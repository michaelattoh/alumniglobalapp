<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\PlatformPaymentSettingUpdateRequest;
use App\Models\PlatformPaymentSetting;
use Illuminate\Http\Request;

class PlatformPaymentSettingController extends Controller
{
    public function show(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $settings = PlatformPaymentSetting::firstOrCreate([]);

        return response()->json([
            'settings' => $this->format($settings),
        ]);
    }

    public function update(PlatformPaymentSettingUpdateRequest $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $settings = PlatformPaymentSetting::firstOrCreate([]);
        $this->applySettings($settings, $request->validated());

        return response()->json([
            'message' => 'Platform payment settings updated',
            'settings' => $this->format($settings),
        ]);
    }

    private function applySettings(PlatformPaymentSetting $settings, array $data): void
    {
        $fields = [
            'stripe_public_key',
            'stripe_secret_key',
            'paystack_public_key',
            'paystack_secret_key',
            'paypal_client_id',
            'paypal_client_secret',
            'flutterwave_public_key',
            'flutterwave_secret_key',
        ];

        foreach ($fields as $field) {
            if (array_key_exists($field, $data)) {
                $value = is_string($data[$field]) ? trim($data[$field]) : $data[$field];
                $settings->{$field} = $value !== '' ? $value : null;
            }
        }

        $settings->save();
    }

    private function format(PlatformPaymentSetting $settings): array
    {
        return [
            'stripe' => [
                'public_key_set' => (bool) $settings->stripe_public_key,
                'secret_key_set' => (bool) $settings->stripe_secret_key,
                'public_key_hint' => $this->maskKey($settings->stripe_public_key),
                'secret_key_hint' => $this->maskKey($settings->stripe_secret_key),
            ],
            'paystack' => [
                'public_key_set' => (bool) $settings->paystack_public_key,
                'secret_key_set' => (bool) $settings->paystack_secret_key,
                'public_key_hint' => $this->maskKey($settings->paystack_public_key),
                'secret_key_hint' => $this->maskKey($settings->paystack_secret_key),
            ],
            'paypal' => [
                'client_id_set' => (bool) $settings->paypal_client_id,
                'client_secret_set' => (bool) $settings->paypal_client_secret,
                'client_id_hint' => $this->maskKey($settings->paypal_client_id),
                'client_secret_hint' => $this->maskKey($settings->paypal_client_secret),
            ],
            'flutterwave' => [
                'public_key_set' => (bool) $settings->flutterwave_public_key,
                'secret_key_set' => (bool) $settings->flutterwave_secret_key,
                'public_key_hint' => $this->maskKey($settings->flutterwave_public_key),
                'secret_key_hint' => $this->maskKey($settings->flutterwave_secret_key),
            ],
        ];
    }

    private function maskKey(?string $value): ?string
    {
        if (!$value) {
            return null;
        }
        $len = strlen($value);
        if ($len <= 8) {
            return str_repeat('•', $len);
        }
        return substr($value, 0, 4) . str_repeat('•', $len - 8) . substr($value, -4);
    }
}
