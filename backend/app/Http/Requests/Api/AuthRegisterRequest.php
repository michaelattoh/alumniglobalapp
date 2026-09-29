<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rules\Password;

class AuthRegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email', 'max:190', 'unique:users,email'],
            'password' => ['required', Password::min(8), 'confirmed'],
            'phone' => ['nullable', 'string', 'max:30'],
            'user_type' => ['required', 'in:alumni,school'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'graduation_year' => ['nullable', 'integer', 'min:2000', 'max:' . (int) now()->format('Y')],
            'school_name' => ['nullable', 'string', 'max:255'],
            'code' => ['nullable', 'string'],
        ];
    }
}
