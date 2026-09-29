<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class DonationCreateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'provider' => ['required', 'in:stripe,paystack,paypal,momo,flutterwave'],
            'amount' => ['required', 'numeric', 'min:1'],
            'currency' => ['required', 'string', 'size:3'],
            'is_anonymous' => ['nullable', 'boolean'],
            'message' => ['nullable', 'string', 'max:500'],
        ];
    }
}
