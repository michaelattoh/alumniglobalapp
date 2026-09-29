<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class AdUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['nullable', 'string', 'max:150'],
            'content' => ['nullable', 'string', 'max:5000'],
            'media_url' => ['nullable', 'url', 'max:500'],
            'target_url' => ['nullable', 'url', 'max:500'],
            'placement' => ['nullable', 'in:feed,story,banner'],
            'pricing_model' => ['nullable', 'in:cpc,cpm,flat'],
            'objective' => ['nullable', 'in:traffic,awareness,conversion'],
            'price' => ['nullable', 'numeric', 'min:0'],
            'budget' => ['nullable', 'numeric', 'min:1'],
            'daily_budget' => ['nullable', 'numeric', 'min:1'],
            'daily_cap_enabled' => ['nullable', 'boolean'],
            'currency' => ['nullable', 'string', 'size:3'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'target_institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'target_location' => ['nullable', 'string', 'max:120'],
            'target_interests' => ['nullable', 'array', 'max:20'],
            'target_interests.*' => ['string', 'max:60'],
            'status' => ['nullable', 'in:active,paused,ended'],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after:starts_at'],
        ];
    }
}
