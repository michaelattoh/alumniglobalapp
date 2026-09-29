<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class InstitutionEmailSettingUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'sender_name' => ['nullable', 'string', 'max:160'],
            'sender_email' => ['nullable', 'email', 'max:190'],
            'smtp_host' => ['nullable', 'string', 'max:190'],
            'smtp_port' => ['nullable', 'integer', 'min:1', 'max:65535'],
            'smtp_username' => ['nullable', 'string', 'max:190'],
            'smtp_password' => ['nullable', 'string', 'max:190'],
            'smtp_encryption' => ['nullable', 'string', 'max:50'],
            'is_enabled' => ['nullable', 'boolean'],
        ];
    }
}
