<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class PlatformPaymentSettingUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'stripe_public_key' => ['nullable', 'string', 'max:255'],
            'stripe_secret_key' => ['nullable', 'string', 'max:255'],
            'paystack_public_key' => ['nullable', 'string', 'max:255'],
            'paystack_secret_key' => ['nullable', 'string', 'max:255'],
            'paypal_client_id' => ['nullable', 'string', 'max:255'],
            'paypal_client_secret' => ['nullable', 'string', 'max:255'],
            'flutterwave_public_key' => ['nullable', 'string', 'max:255'],
            'flutterwave_secret_key' => ['nullable', 'string', 'max:255'],
        ];
    }
}
