<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\PaymentInitiateRequest;
use App\Http\Requests\Api\PaymentRefundRequest;
use App\Http\Requests\Api\SubscriptionStoreRequest;
use App\Http\Resources\Api\PaymentTransactionResource;
use App\Http\Resources\Api\SubscriptionResource;
use App\Models\AuditLog;
use App\Models\InstitutionPaymentSetting;
use App\Models\PaymentTransaction;
use App\Models\Subscription;
use App\Models\SystemSetting;
use App\Models\User;
use App\Services\NotificationService;
use App\Services\ReceiptService;
use App\Services\Payments\PaymentGateway;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class PaymentController extends Controller
{
    public function initiate(PaymentInitiateRequest $request)
    {
        $user = $request->user();
        $data = $request->validated();

        $institutionId = $data['institution_id'] ?? $user->institution_id;
        $settings = InstitutionPaymentSetting::where('institution_id', $institutionId)->first();
        if (!$settings || !$settings->hasProvider(strtolower($data['provider']))) {
            return response()->json(['message' => 'Payment provider not configured for this institution.'], 422);
        }

        $transaction = PaymentTransaction::create([
            'user_id' => $user->id,
            'institution_id' => $institutionId,
            'type' => $data['type'],
            'provider' => $data['provider'],
            'status' => 'pending',
            'amount' => $data['amount'],
            'currency' => strtoupper($data['currency']),
            'reference' => 'TXN-' . Str::upper(Str::random(12)),
            'provider_reference' => null,
            'metadata' => $data['metadata'] ?? [],
            'paid_at' => null,
        ]);

        $returnUrl = rtrim(config('app.url'), '/') . '/payments/return?provider=' . strtolower($data['provider']) . '&reference=' . $transaction->reference;
        $gateway = PaymentGateway::initiate(strtolower($data['provider']), $settings, [
            'amount' => $data['amount'],
            'currency' => strtoupper($data['currency']),
            'reference' => $transaction->reference,
            'email' => $user->email,
            'customer_name' => $user->name,
            'title' => ucfirst($data['type']) . ' payment',
            'description' => ucfirst($data['type']),
            'return_url' => $returnUrl,
            'metadata' => array_merge($data['metadata'] ?? [], ['transaction_id' => $transaction->id]),
            'paypal_mode' => config('services.paypal.mode', 'live'),
        ]);

        if (!($gateway['ok'] ?? false)) {
            $transaction->update([
                'status' => 'failed',
                'metadata' => array_merge($transaction->metadata ?? [], ['gateway_error' => $gateway['message'] ?? 'init_failed']),
            ]);
            return response()->json([
                'message' => $gateway['message'] ?? 'Payment initialization failed',
            ], 422);
        }

        $transaction->update([
            'provider_reference' => $gateway['provider_reference'] ?? null,
            'metadata' => array_merge($transaction->metadata ?? [], [
                'checkout_url' => $gateway['checkout_url'] ?? null,
                'gateway_raw' => $gateway['raw'] ?? null,
            ]),
        ]);

        $this->notifyAccountingTeam(
            $transaction->fresh(['user', 'institution']),
            'payment_pending',
            'New payment requires follow-up',
            $user->name . ' started a ' . str_replace('_', ' ', $transaction->type) . ' payment that is still pending.',
            '/accounting/transactions'
        );

        return response()->json([
            'message' => 'Payment initiated',
            'transaction' => new PaymentTransactionResource($transaction),
            'checkout_url' => $gateway['checkout_url'] ?? null,
        ], 201);
    }

    public function history(Request $request)
    {
        $actor = $request->user();

        $transactions = PaymentTransaction::query()
            ->with([
                'user:id,name,email',
                'institution:id,name',
            ])
            ->latest();

        if ($actor->role === 'institution_admin' && $actor->institution_id) {
            $transactions->where('institution_id', $actor->institution_id);
        } else {
            $transactions->where('user_id', $actor->id);
        }

        $transactions = $transactions->paginate((int) $request->query('per_page', 30));

        return $this->paginatedResponse($transactions, PaymentTransactionResource::class);
    }

    public function refund(PaymentRefundRequest $request, PaymentTransaction $transaction)
    {
        $actor = $request->user();
        $isAdmin = in_array($actor->role, ['super_admin', 'institution_admin'], true);
        $sameInstitution = $actor->institution_id && (int) $transaction->institution_id === (int) $actor->institution_id;
        if (!$isAdmin && (int) $transaction->user_id !== (int) $actor->id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && !$sameInstitution) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($transaction->status !== 'success') {
            return response()->json(['message' => 'Only successful transactions can be refunded'], 422);
        }

        $data = $request->validated();
        $refundAmount = (float) ($data['amount'] ?? $transaction->amount);

        $refund = PaymentTransaction::create([
            'user_id' => $transaction->user_id,
            'institution_id' => $transaction->institution_id,
            'type' => 'refund',
            'provider' => $transaction->provider,
            'status' => 'success',
            'amount' => $refundAmount,
            'currency' => $transaction->currency,
            'reference' => 'RFD-' . Str::upper(Str::random(12)),
            'provider_reference' => 'PROV-R-' . Str::upper(Str::random(8)),
            'refunded_transaction_id' => $transaction->id,
            'metadata' => ['reason' => $data['reason'] ?? null],
            'paid_at' => now(),
        ]);
        $refundReceiptUrl = app(ReceiptService::class)->generate($refund);
        if ($refundReceiptUrl) {
            $refund->update(['receipt_url' => $refundReceiptUrl]);
        }

        $transaction->update([
            'status' => 'refunded',
            'refunded_at' => now(),
        ]);

        AuditLog::record($actor, 'payment.refund', PaymentTransaction::class, $transaction->id, [
            'refund_id' => $refund->id,
            'amount' => $refundAmount,
        ], $request);

        $this->notifyAccountingTeam(
            $refund->fresh(['user', 'institution']),
            'payment_refunded',
            'Refund processed',
            ($actor->name ?: 'An admin') . ' refunded ' . strtoupper((string) $refund->currency) . ' ' . number_format((float) $refundAmount, 2) . '.',
            '/accounting/transactions'
        );

        return response()->json([
            'message' => 'Refund processed',
            'transaction' => new PaymentTransactionResource($refund),
        ]);
    }

    public function subscribe(SubscriptionStoreRequest $request)
    {
        $user = $request->user();
        $data = $request->validated();

        $subscription = Subscription::create([
            'user_id' => $user->id,
            'institution_id' => $data['institution_id'] ?? $user->institution_id,
            'plan_name' => $data['plan_name'],
            'interval' => $data['interval'],
            'amount' => $data['amount'],
            'currency' => strtoupper($data['currency']),
            'provider' => $data['provider'],
            'provider_reference' => 'SUB-' . Str::upper(Str::random(10)),
            'status' => 'active',
            'starts_at' => now(),
            'ends_at' => $data['interval'] === 'yearly' ? now()->addYear() : now()->addMonth(),
        ]);

        $subscriptionTx = PaymentTransaction::create([
            'user_id' => $user->id,
            'institution_id' => $subscription->institution_id,
            'type' => 'subscription',
            'provider' => $data['provider'],
            'status' => 'success',
            'amount' => $data['amount'],
            'currency' => strtoupper($data['currency']),
            'reference' => 'TXN-' . Str::upper(Str::random(12)),
            'provider_reference' => 'PROV-' . Str::upper(Str::random(10)),
            'metadata' => ['subscription_id' => $subscription->id],
            'paid_at' => now(),
        ]);
        $subReceiptUrl = app(ReceiptService::class)->generate($subscriptionTx);
        if ($subReceiptUrl) {
            $subscriptionTx->update(['receipt_url' => $subReceiptUrl]);
        }

        $this->notifyAccountingTeam(
            $subscriptionTx->fresh(['user', 'institution']),
            'subscription_payment',
            'New subscription payment',
            $user->name . ' started the ' . $subscription->plan_name . ' subscription.',
            '/accounting/subscriptions'
        );

        return response()->json([
            'message' => 'Subscription created',
            'subscription' => new SubscriptionResource($subscription),
        ], 201);
    }

    private function notifyAccountingTeam(
        PaymentTransaction $transaction,
        string $type,
        string $title,
        string $body,
        string $route
    ): void {
        $notifications = app(NotificationService::class);

        foreach ($this->accountingUsers() as $accountant) {
            $notifications->notify(
                (int) $accountant->id,
                $type,
                $title,
                $body,
                [
                    'screen' => 'payments',
                    'route' => $route,
                    'transaction_id' => (string) $transaction->id,
                    'reference' => (string) $transaction->reference,
                    'status' => (string) $transaction->status,
                    'amount' => (string) $transaction->amount,
                    'currency' => (string) $transaction->currency,
                    'type' => (string) $transaction->type,
                ]
            );
        }
    }

    private function accountingUsers()
    {
        $roleCatalog = SystemSetting::query()->where('key', 'role_catalog')->value('value');
        $portalRoles = collect(is_array($roleCatalog) ? $roleCatalog : [])
            ->filter(fn ($config) => is_array($config) && ($config['portal'] ?? null) === 'accounting')
            ->keys()
            ->values()
            ->all();

        $roles = array_values(array_unique(array_merge(['accountant'], $portalRoles)));

        return User::query()
            ->whereIn('role', $roles)
            ->get();
    }
}
