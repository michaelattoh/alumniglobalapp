<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class EventUpdateRequest extends FormRequest
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
            'event_type' => ['sometimes', 'in:physical,virtual,fair,workshop'],
            'location' => ['sometimes', 'nullable', 'string', 'max:200'],
            'meeting_url' => ['sometimes', 'nullable', 'url', 'max:500'],
            'starts_at' => ['sometimes', 'date'],
            'ends_at' => ['sometimes', 'nullable', 'date', 'after:starts_at'],
            'institution_id' => ['sometimes', 'nullable', 'integer', 'exists:institutions,id'],
            'capacity' => ['sometimes', 'nullable', 'integer', 'min:1'],
            'is_paid' => ['sometimes', 'boolean'],
            'price' => ['sometimes', 'nullable', 'numeric', 'min:0'],
            'currency' => ['sometimes', 'nullable', 'string', 'size:3'],
            'payment_provider' => ['sometimes', 'nullable', 'string', 'max:50'],
            'payment_reference' => ['sometimes', 'nullable', 'string', 'max:120'],
            'is_active' => ['sometimes', 'boolean'],
        ];
    }
}
