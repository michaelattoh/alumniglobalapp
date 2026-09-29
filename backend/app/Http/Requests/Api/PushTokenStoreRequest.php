<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PushTokenStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'token' => ['required', 'string', 'max:255'],
            'platform' => ['nullable', Rule::in(['android', 'ios', 'web', 'unknown'])],
            'device_id' => ['nullable', 'string', 'max:120'],
        ];
    }
}
