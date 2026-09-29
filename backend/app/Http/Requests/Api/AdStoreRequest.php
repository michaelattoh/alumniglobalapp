<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class AdStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:150'],
            'content' => ['nullable', 'string', 'max:5000'],
            'media_url' => ['nullable', 'url', 'max:500'],
            'target_url' => ['nullable', 'url', 'max:500'],
            'placement' => ['required', 'in:feed,story,banner'],
            'pricing_model' => ['required', 'in:cpc,cpm,flat'],
            'objective' => ['nullable', 'in:traffic,awareness,conversion'],
            'price' => ['required', 'numeric', 'min:0'],
            'budget' => ['required', 'numeric', 'min:1'],
            'daily_budget' => ['nullable', 'numeric', 'min:1'],
            'daily_cap_enabled' => ['nullable', 'boolean'],
            'currency' => ['required', 'string', 'size:3'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'target_institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'target_location' => ['nullable', 'string', 'max:120'],
            'target_interests' => ['nullable', 'array', 'max:20'],
            'target_interests.*' => ['string', 'max:60'],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after:starts_at'],
        ];
    }
}
