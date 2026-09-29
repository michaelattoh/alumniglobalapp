<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class AiControlUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'feed_personalization_enabled' => ['nullable', 'boolean'],
            'recommendations_enabled' => ['nullable', 'boolean'],
            'max_daily_recommendations' => ['nullable', 'integer', 'min:1', 'max:100000'],
            'guardrails' => ['nullable', 'array'],
        ];
    }
}
