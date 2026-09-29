<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class PaymentRefundRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'amount' => ['nullable', 'numeric', 'min:0.01'],
            'reason' => ['nullable', 'string', 'max:500'],
        ];
    }
}
