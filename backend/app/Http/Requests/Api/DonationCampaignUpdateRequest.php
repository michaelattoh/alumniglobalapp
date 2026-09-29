<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class DonationCampaignUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['sometimes', 'string', 'max:150'],
            'description' => ['sometimes', 'nullable', 'string', 'max:5000'],
            'image_url' => ['sometimes', 'nullable', 'string', 'max:2048'],
            'target_amount' => ['sometimes', 'numeric', 'min:1'],
            'currency' => ['sometimes', 'string', 'size:3'],
            'institution_id' => ['sometimes', 'nullable', 'integer', 'exists:institutions,id'],
            'starts_at' => ['sometimes', 'nullable', 'date'],
            'ends_at' => ['sometimes', 'nullable', 'date', 'after:starts_at'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }
}
