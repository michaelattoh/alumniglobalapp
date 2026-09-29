<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\InstitutionPaymentSetting;
use App\Models\Donation;
use App\Models\PaymentTransaction;
use App\Models\SystemSetting;
use App\Models\User;
use App\Services\NotificationService;
use App\Services\Payments\PaymentGateway;
use Illuminate\Http\Request;

class PaymentReturnController extends Controller
{
    public function __invoke(Request $request)
    {
        $provider = strtolower($request->query('provider', ''));
        $reference = $request->query('reference');
        $sessionId = $request->query('session_id');
        $status = $request->query('status', '');

        if (!$reference && !$sessionId) {
            return response('Payment response received. You can close this page.', 200);
        }

        $transaction = PaymentTransaction::query()
            ->when($reference, function ($q) use ($reference) {
                $q->where('reference', $reference)->orWhere('provider_reference', $reference);
            })
            ->when(!$reference && $sessionId, function ($q) use ($sessionId) {
                $q->where('provider_reference', $sessionId);
            })
            ->first();

        if (!$transaction) {
            return response('Payment pending. Please return to the app.', 200);
        }

        $settings = InstitutionPaymentSetting::where('institution_id', $transaction->institution_id)->first();
        if (!$settings) {
            return response('Payment pending. Please return to the app.', 200);
        }

        if ($provider === 'paystack' && $reference) {
            $result = PaymentGateway::verifyPaystack($settings, $reference);
            if (($result['status'] ?? '') === 'success') {
                $this->markSuccess($transaction, $result['raw'] ?? []);
            }
        }

        if ($provider === 'flutterwave' && $reference) {
            $result = PaymentGateway::verifyFlutterwave($settings, $reference);
            if (($result['status'] ?? '') === 'success') {
                $this->markSuccess($transaction, $result['raw'] ?? []);
            }
        }

        if ($provider === 'stripe' && $sessionId) {
            $result = PaymentGateway::verifyStripeSession($settings, $sessionId);
            if (($result['status'] ?? '') === 'success') {
                $transaction->update(['provider_reference' => $result['provider_reference'] ?? $sessionId]);
                $this->markSuccess($transaction, $result['raw'] ?? []);
            }
        }

        if ($provider === 'paypal' && $reference) {
            PaymentGateway::capturePaypalOrder($settings, $reference, config('services.paypal.mode', 'live'));
            $transaction->update(['provider_reference' => $reference]);
            $this->markSuccess($transaction, []);
        }

        return response('Payment processed. You can close this page.', 200);
    }

    private function markSuccess(PaymentTransaction $transaction, array $payload = []): void
    {
        if ($transaction->status === 'success') {
            return;
        }

        $transaction->update([
            'status' => 'success',
            'paid_at' => now(),
            'metadata' => array_merge($transaction->metadata ?? [], ['provider_payload' => $payload]),
        ]);

        Donation::query()
            ->where('transaction_id', $transaction->id)
            ->update(['status' => 'success']);

        PaymentTransaction::query()
            ->where('type', 'platform_fee')
            ->where('status', 'pending')
            ->where('metadata->donation_transaction_id', $transaction->id)
            ->update(['status' => 'success', 'paid_at' => now()]);

        if ($transaction->type === 'donation') {
            $donation = Donation::query()
                ->with(['campaign:id,title,created_by'])
                ->where('transaction_id', $transaction->id)
                ->first();
            if ($donation) {
                $donation->campaign()->update([
                    'raised_amount' => $donation->campaign->raised_amount + $donation->amount,
                ]);
                $this->notifyDonationSuccess($transaction, $donation);
            }
        }

        $this->notifyAccountingTeam($transaction->fresh(['user', 'institution']));
    }

    private function notifyDonationSuccess(PaymentTransaction $transaction, Donation $donation): void
    {
        $campaign = $donation->campaign;
        if (!$campaign) {
            return;
        }

        $amount = number_format((float) $donation->amount, 2);
        $currency = strtoupper((string) $donation->currency);
        $payload = [
            'campaign_id' => $campaign->id,
            'donation_id' => $donation->id,
            'transaction_id' => $transaction->id,
        ];

        $notifications = app(NotificationService::class);
        $notifications->notify(
            (int) $donation->user_id,
            'donation',
            'Donation successful',
            "Your donation of {$currency} {$amount} to {$campaign->title} was successful.",
            $payload
        );

        if ((int) $campaign->created_by !== (int) $donation->user_id) {
            $notifications->notify(
                (int) $campaign->created_by,
                'donation',
                'New donation received',
                "A donation of {$currency} {$amount} was received for {$campaign->title}.",
                $payload
            );
        }
    }

    private function notifyAccountingTeam(PaymentTransaction $transaction): void
    {
        $notifications = app(NotificationService::class);
        $transaction = $transaction->fresh(['user', 'institution']);
        $body = ($transaction->user?->name ?: 'A user') . ' completed a ' . str_replace('_', ' ', (string) $transaction->type) . ' payment.';

        foreach ($this->accountingUsers() as $accountant) {
            $notifications->notify(
                (int) $accountant->id,
                'payment_success',
                'Payment completed',
                $body,
                [
                    'screen' => 'payments',
                    'route' => '/accounting/transactions',
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
