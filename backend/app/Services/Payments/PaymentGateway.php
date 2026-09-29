<?php

namespace App\Services\Payments;

use App\Models\InstitutionPaymentSetting;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class PaymentGateway
{
    public static function initiate(
        string $provider,
        InstitutionPaymentSetting $settings,
        array $payload
    ): array {
        $provider = strtolower($provider);
        return match ($provider) {
            'paystack', 'momo' => self::initPaystack($settings, $payload, $provider === 'momo'),
            'flutterwave' => self::initFlutterwave($settings, $payload),
            'stripe' => self::initStripe($settings, $payload),
            'paypal' => self::initPaypal($settings, $payload),
            default => [
                'ok' => false,
                'message' => 'Unsupported payment provider',
            ],
        };
    }

    public static function verifyPaystack(InstitutionPaymentSetting $settings, string $reference): array
    {
        $secret = $settings->paystack_secret_key;
        if (!$secret) {
            return ['ok' => false, 'message' => 'Paystack not configured'];
        }
        $res = Http::withToken($secret)
            ->get('https://api.paystack.co/transaction/verify/' . urlencode($reference));
        if (!$res->ok()) {
            return ['ok' => false, 'message' => 'Paystack verification failed', 'raw' => $res->json()];
        }
        $data = $res->json('data') ?? [];
        $status = ($data['status'] ?? '') === 'success' ? 'success' : 'failed';
        return [
            'ok' => true,
            'status' => $status,
            'reference' => $data['reference'] ?? $reference,
            'provider_reference' => $data['reference'] ?? $reference,
            'raw' => $res->json(),
        ];
    }

    public static function verifyFlutterwave(InstitutionPaymentSetting $settings, string $txRef): array
    {
        $secret = $settings->flutterwave_secret_key;
        if (!$secret) {
            return ['ok' => false, 'message' => 'Flutterwave not configured'];
        }
        $res = Http::withToken($secret)
            ->get('https://api.flutterwave.com/v3/transactions/verify_by_reference', [
                'tx_ref' => $txRef,
            ]);
        if (!$res->ok()) {
            return ['ok' => false, 'message' => 'Flutterwave verification failed', 'raw' => $res->json()];
        }
        $data = $res->json('data') ?? [];
        $status = strtolower($data['status'] ?? '') === 'successful' ? 'success' : 'failed';
        return [
            'ok' => true,
            'status' => $status,
            'reference' => $data['tx_ref'] ?? $txRef,
            'provider_reference' => (string) ($data['id'] ?? $txRef),
            'raw' => $res->json(),
        ];
    }

    public static function verifyStripeSession(InstitutionPaymentSetting $settings, string $sessionId): array
    {
        $secret = $settings->stripe_secret_key;
        if (!$secret) {
            return ['ok' => false, 'message' => 'Stripe not configured'];
        }
        $res = Http::withToken($secret)
            ->asForm()
            ->get('https://api.stripe.com/v1/checkout/sessions/' . urlencode($sessionId));
        if (!$res->ok()) {
            return ['ok' => false, 'message' => 'Stripe verification failed', 'raw' => $res->json()];
        }
        $data = $res->json() ?? [];
        $status = ($data['payment_status'] ?? '') === 'paid' ? 'success' : 'failed';
        return [
            'ok' => true,
            'status' => $status,
            'reference' => $data['client_reference_id'] ?? null,
            'provider_reference' => $data['id'] ?? $sessionId,
            'raw' => $data,
        ];
    }

    public static function paypalAccessToken(InstitutionPaymentSetting $settings, string $mode = 'live'): ?string
    {
        $clientId = $settings->paypal_client_id;
        $secret = $settings->paypal_client_secret;
        if (!$clientId || !$secret) {
            return null;
        }
        $base = $mode === 'sandbox' ? 'https://api-m.sandbox.paypal.com' : 'https://api-m.paypal.com';
        $res = Http::withBasicAuth($clientId, $secret)
            ->asForm()
            ->post($base . '/v1/oauth2/token', [
                'grant_type' => 'client_credentials',
            ]);
        if (!$res->ok()) return null;
        return $res->json('access_token');
    }

    public static function capturePaypalOrder(InstitutionPaymentSetting $settings, string $orderId, string $mode = 'live'): array
    {
        $token = self::paypalAccessToken($settings, $mode);
        if (!$token) {
            return ['ok' => false, 'message' => 'PayPal auth failed'];
        }
        $base = $mode === 'sandbox' ? 'https://api-m.sandbox.paypal.com' : 'https://api-m.paypal.com';
        $res = Http::withToken($token)->post($base . '/v2/checkout/orders/' . urlencode($orderId) . '/capture');
        if (!$res->ok()) {
            return ['ok' => false, 'message' => 'PayPal capture failed', 'raw' => $res->json()];
        }
        return ['ok' => true, 'raw' => $res->json()];
    }

    public static function verifyPaypalWebhook(
        InstitutionPaymentSetting $settings,
        array $headers,
        array $body,
        string $webhookId,
        string $mode = 'live'
    ): bool {
        $token = self::paypalAccessToken($settings, $mode);
        if (!$token) return false;

        $base = $mode === 'sandbox' ? 'https://api-m.sandbox.paypal.com' : 'https://api-m.paypal.com';
        $payload = [
            'auth_algo' => $headers['paypal-auth-algo'] ?? null,
            'cert_url' => $headers['paypal-cert-url'] ?? null,
            'transmission_id' => $headers['paypal-transmission-id'] ?? null,
            'transmission_sig' => $headers['paypal-transmission-sig'] ?? null,
            'transmission_time' => $headers['paypal-transmission-time'] ?? null,
            'webhook_id' => $webhookId,
            'webhook_event' => $body,
        ];
        $res = Http::withToken($token)->post($base . '/v1/notifications/verify-webhook-signature', $payload);
        return $res->ok() && ($res->json('verification_status') === 'SUCCESS');
    }

    private static function initPaystack(InstitutionPaymentSetting $settings, array $payload, bool $momo = false): array
    {
        $secret = $settings->paystack_secret_key;
        if (!$secret) {
            return ['ok' => false, 'message' => 'Paystack not configured'];
        }
        $amount = (int) round(((float) $payload['amount']) * 100);
        $reference = $payload['reference'] ?? ('TXN-' . Str::upper(Str::random(12)));
        $data = [
            'email' => $payload['email'] ?? 'support@alumniglobalnetwork.com',
            'amount' => $amount,
            'currency' => strtoupper($payload['currency'] ?? 'GHS'),
            'reference' => $reference,
            'callback_url' => $payload['return_url'] ?? null,
            'metadata' => $payload['metadata'] ?? [],
        ];
        if ($momo) {
            $data['channels'] = ['mobile_money'];
        }
        $res = Http::withToken($secret)
            ->post('https://api.paystack.co/transaction/initialize', array_filter($data, fn($v) => $v !== null));
        if (!$res->ok()) {
            return ['ok' => false, 'message' => 'Paystack init failed', 'raw' => $res->json()];
        }
        $payload = $res->json('data') ?? [];
        return [
            'ok' => true,
            'checkout_url' => $payload['authorization_url'] ?? null,
            'provider_reference' => $payload['reference'] ?? $reference,
            'raw' => $res->json(),
        ];
    }

    private static function initFlutterwave(InstitutionPaymentSetting $settings, array $payload): array
    {
        $secret = $settings->flutterwave_secret_key;
        if (!$secret) {
            return ['ok' => false, 'message' => 'Flutterwave not configured'];
        }
        $txRef = $payload['reference'] ?? ('TXN-' . Str::upper(Str::random(12)));
        $res = Http::withToken($secret)
            ->post('https://api.flutterwave.com/v3/payments', [
                'tx_ref' => $txRef,
                'amount' => (float) $payload['amount'],
                'currency' => strtoupper($payload['currency'] ?? 'GHS'),
                'redirect_url' => $payload['return_url'] ?? null,
                'customer' => [
                    'email' => $payload['email'] ?? 'support@alumniglobalnetwork.com',
                    'name' => $payload['customer_name'] ?? 'Alumni Global Network',
                ],
                'customizations' => [
                    'title' => $payload['title'] ?? 'Alumni Global Network',
                    'description' => $payload['description'] ?? 'Donation',
                ],
                'meta' => $payload['metadata'] ?? [],
            ]);
        if (!$res->ok()) {
            return ['ok' => false, 'message' => 'Flutterwave init failed', 'raw' => $res->json()];
        }
        $data = $res->json('data') ?? [];
        return [
            'ok' => true,
            'checkout_url' => $data['link'] ?? null,
            'provider_reference' => $txRef,
            'raw' => $res->json(),
        ];
    }

    private static function initStripe(InstitutionPaymentSetting $settings, array $payload): array
    {
        $secret = $settings->stripe_secret_key;
        if (!$secret) {
            return ['ok' => false, 'message' => 'Stripe not configured'];
        }
        $amount = (int) round(((float) $payload['amount']) * 100);
        $currency = strtolower($payload['currency'] ?? 'usd');
        $reference = $payload['reference'] ?? ('TXN-' . Str::upper(Str::random(12)));
        $returnUrl = $payload['return_url'] ?? null;
        $success = $returnUrl ? ($returnUrl . '&status=success&session_id={CHECKOUT_SESSION_ID}') : null;
        $cancel = $returnUrl ? ($returnUrl . '&status=cancel') : null;

        $res = Http::withToken($secret)
            ->asForm()
            ->post('https://api.stripe.com/v1/checkout/sessions', [
                'mode' => 'payment',
                'success_url' => $success ?? 'https://example.com',
                'cancel_url' => $cancel ?? 'https://example.com',
                'client_reference_id' => $reference,
                'customer_email' => $payload['email'] ?? null,
                'line_items[0][price_data][currency]' => $currency,
                'line_items[0][price_data][unit_amount]' => $amount,
                'line_items[0][price_data][product_data][name]' => $payload['title'] ?? 'Donation',
                'line_items[0][quantity]' => 1,
                'metadata[transaction_reference]' => $reference,
            ]);
        if (!$res->ok()) {
            return ['ok' => false, 'message' => 'Stripe init failed', 'raw' => $res->json()];
        }
        $data = $res->json() ?? [];
        return [
            'ok' => true,
            'checkout_url' => $data['url'] ?? null,
            'provider_reference' => $data['id'] ?? $reference,
            'raw' => $data,
        ];
    }

    private static function initPaypal(InstitutionPaymentSetting $settings, array $payload): array
    {
        $mode = $payload['paypal_mode'] ?? $settings->paypal_mode ?? 'live';
        $token = self::paypalAccessToken($settings, $mode);
        if (!$token) {
            return ['ok' => false, 'message' => 'PayPal auth failed'];
        }
        $base = $mode === 'sandbox' ? 'https://api-m.sandbox.paypal.com' : 'https://api-m.paypal.com';
        $reference = $payload['reference'] ?? ('TXN-' . Str::upper(Str::random(12)));
        $returnUrl = $payload['return_url'] ?? null;

        $res = Http::withToken($token)
            ->post($base . '/v2/checkout/orders', [
                'intent' => 'CAPTURE',
                'purchase_units' => [[
                    'reference_id' => $reference,
                    'amount' => [
                        'currency_code' => strtoupper($payload['currency'] ?? 'USD'),
                        'value' => number_format((float) $payload['amount'], 2, '.', ''),
                    ],
                ]],
                'application_context' => [
                    'brand_name' => $payload['title'] ?? 'Alumni Global Network',
                    'return_url' => $returnUrl ?? 'https://example.com',
                    'cancel_url' => $returnUrl ? ($returnUrl . '&status=cancel') : 'https://example.com',
                ],
            ]);
        if (!$res->ok()) {
            return ['ok' => false, 'message' => 'PayPal init failed', 'raw' => $res->json()];
        }
        $data = $res->json() ?? [];
        $approveUrl = null;
        foreach ($data['links'] ?? [] as $link) {
            if (($link['rel'] ?? '') === 'approve') {
                $approveUrl = $link['href'] ?? null;
                break;
            }
        }
        return [
            'ok' => true,
            'checkout_url' => $approveUrl,
            'provider_reference' => $data['id'] ?? $reference,
            'raw' => $data,
        ];
    }
}
