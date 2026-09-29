<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class PaymentInitiateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'type' => ['required', 'in:donation,event_ticket,membership_fee,subscription'],
            'provider' => ['required', 'in:stripe,paystack,paypal,momo,flutterwave'],
            'amount' => ['required', 'numeric', 'min:1'],
            'currency' => ['required', 'string', 'size:3'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'metadata' => ['nullable', 'array'],
        ];
    }
}
