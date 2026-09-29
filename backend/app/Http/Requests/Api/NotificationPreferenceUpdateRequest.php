<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class NotificationPreferenceUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'in_app_enabled' => ['nullable', 'boolean'],
            'push_enabled' => ['nullable', 'boolean'],
            'email_enabled' => ['nullable', 'boolean'],
            'messages_enabled' => ['nullable', 'boolean'],
            'connections_enabled' => ['nullable', 'boolean'],
            'events_enabled' => ['nullable', 'boolean'],
            'ai_personalization_enabled' => ['nullable', 'boolean'],
        ];
    }
}
