<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class SubscriptionStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'plan_name' => ['required', 'string', 'max:120'],
            'interval' => ['required', 'in:monthly,yearly'],
            'amount' => ['required', 'numeric', 'min:1'],
            'currency' => ['required', 'string', 'size:3'],
            'provider' => ['required', 'in:stripe,paystack,flutterwave'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
        ];
    }
}
