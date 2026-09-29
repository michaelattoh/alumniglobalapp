<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Donation;
use App\Models\InstitutionPaymentSetting;
use App\Models\PaymentTransaction;
use App\Models\SystemSetting;
use App\Models\User;
use App\Services\NotificationService;
use App\Services\Payments\PaymentGateway;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class PaymentWebhookController extends Controller
{
    public function paystack(Request $request)
    {
        $secret = config('services.paystack.webhook_secret');
        $signature = $request->header('x-paystack-signature');
        if ($secret && $signature) {
            $hash = hash_hmac('sha512', $request->getContent(), $secret);
            if (!hash_equals($hash, $signature)) {
                return response()->json(['message' => 'Invalid signature'], 401);
            }
        }

        $event = $request->input('event');
        if ($event !== 'charge.success') {
            return response()->json(['message' => 'Ignored'], 200);
        }

        $data = $request->input('data', []);
        $reference = $data['reference'] ?? null;
        if (!$reference) {
            return response()->json(['message' => 'Missing reference'], 422);
        }

        $transaction = PaymentTransaction::query()
            ->where('reference', $reference)
            ->orWhere('provider_reference', $reference)
            ->first();

        if (!$transaction) {
            return response()->json(['message' => 'Transaction not found'], 404);
        }

        $this->markTransactionSuccess($transaction, $data);
        return response()->json(['message' => 'OK']);
    }

    public function flutterwave(Request $request)
    {
        $secret = config('services.flutterwave.webhook_secret');
        $signature = $request->header('verif-hash');
        if ($secret && $signature && $secret !== $signature) {
            return response()->json(['message' => 'Invalid signature'], 401);
        }

        $event = $request->input('event') ?? '';
        if (!Str::contains($event, 'charge') && !Str::contains($event, 'payment')) {
            return response()->json(['message' => 'Ignored'], 200);
        }

        $data = $request->input('data', []);
        $txRef = $data['tx_ref'] ?? null;
        if (!$txRef) {
            return response()->json(['message' => 'Missing reference'], 422);
        }

        $transaction = PaymentTransaction::query()
            ->where('reference', $txRef)
            ->orWhere('provider_reference', (string) ($data['id'] ?? ''))
            ->first();

        if (!$transaction) {
            return response()->json(['message' => 'Transaction not found'], 404);
        }

        if (($data['status'] ?? '') !== 'successful') {
            return response()->json(['message' => 'Ignored'], 200);
        }

        $this->markTransactionSuccess($transaction, $data);
        return response()->json(['message' => 'OK']);
    }

    public function stripe(Request $request)
    {
        $secret = config('services.stripe.webhook_secret');
        if ($secret) {
            $signature = $request->header('stripe-signature');
            if (!$signature) {
                return response()->json(['message' => 'Missing signature'], 401);
            }
            $parts = collect(explode(',', $signature))
                ->mapWithKeys(function ($item) {
                    [$k, $v] = array_pad(explode('=', $item, 2), 2, null);
                    return [$k => $v];
                });
            $timestamp = $parts->get('t');
            $sig = $parts->get('v1');
            if ($timestamp && $sig) {
                $signedPayload = $timestamp . '.' . $request->getContent();
                $hash = hash_hmac('sha256', $signedPayload, $secret);
                if (!hash_equals($hash, $sig)) {
                    return response()->json(['message' => 'Invalid signature'], 401);
                }
            }
        }

        $type = $request->input('type');
        if ($type !== 'checkout.session.completed') {
            return response()->json(['message' => 'Ignored'], 200);
        }

        $session = $request->input('data.object', []);
        $reference = $session['client_reference_id'] ?? ($session['metadata']['transaction_reference'] ?? null);
        if (!$reference) {
            return response()->json(['message' => 'Missing reference'], 422);
        }

        $transaction = PaymentTransaction::query()->where('reference', $reference)->first();
        if (!$transaction) {
            return response()->json(['message' => 'Transaction not found'], 404);
        }

        $this->markTransactionSuccess($transaction, $session);
        return response()->json(['message' => 'OK']);
    }

    public function paypal(Request $request)
    {
        $event = $request->input('event_type');
        if (!in_array($event, ['PAYMENT.CAPTURE.COMPLETED', 'CHECKOUT.ORDER.APPROVED'], true)) {
            return response()->json(['message' => 'Ignored'], 200);
        }

        $resource = $request->input('resource', []);
        $orderId = $resource['id'] ?? null;
        if (!$orderId) {
            return response()->json(['message' => 'Missing order id'], 422);
        }

        $transaction = PaymentTransaction::query()
            ->where('provider_reference', $orderId)
            ->first();

        if (!$transaction) {
            return response()->json(['message' => 'Transaction not found'], 404);
        }

        $webhookId = config('services.paypal.webhook_id');
        $settings = InstitutionPaymentSetting::where('institution_id', $transaction->institution_id)->first();
        if ($webhookId && $settings) {
            $headers = [
                'paypal-auth-algo' => $request->header('paypal-auth-algo'),
                'paypal-cert-url' => $request->header('paypal-cert-url'),
                'paypal-transmission-id' => $request->header('paypal-transmission-id'),
                'paypal-transmission-sig' => $request->header('paypal-transmission-sig'),
                'paypal-transmission-time' => $request->header('paypal-transmission-time'),
            ];
            $mode = $settings->paypal_mode ?: config('services.paypal.mode', 'live');
            $verified = PaymentGateway::verifyPaypalWebhook(
                $settings,
                $headers,
                $request->all(),
                $webhookId,
                $mode
            );
            if (!$verified) {
                return response()->json(['message' => 'Invalid signature'], 401);
            }
        }

        if ($event === 'CHECKOUT.ORDER.APPROVED') {
            if ($settings) {
                $mode = $settings->paypal_mode ?: config('services.paypal.mode', 'live');
                PaymentGateway::capturePaypalOrder($settings, $orderId, $mode);
            }
        }

        $this->markTransactionSuccess($transaction, $resource);
        return response()->json(['message' => 'OK']);
    }

    private function markTransactionSuccess(PaymentTransaction $transaction, array $payload = []): void
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
