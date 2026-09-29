<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class EventStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:150'],
            'description' => ['nullable', 'string', 'max:5000'],
            'event_type' => ['required', 'in:physical,virtual,fair,workshop'],
            'location' => ['nullable', 'string', 'max:200'],
            'meeting_url' => ['nullable', 'url', 'max:500'],
            'starts_at' => ['required', 'date', 'after:now'],
            'ends_at' => ['nullable', 'date', 'after:starts_at'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'capacity' => ['nullable', 'integer', 'min:1'],
            'is_paid' => ['nullable', 'boolean'],
            'price' => ['nullable', 'numeric', 'min:0'],
            'currency' => ['nullable', 'string', 'size:3'],
            'payment_provider' => ['nullable', 'string', 'max:50'],
            'payment_reference' => ['nullable', 'string', 'max:120'],
        ];
    }
}
