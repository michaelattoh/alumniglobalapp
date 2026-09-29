<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class EventRsvpRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', 'in:going,interested,not_going'],
            'reminder_enabled' => ['nullable', 'boolean'],
            'reminder_at' => ['nullable', 'date'],
        ];
    }
}
