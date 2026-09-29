<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class AdminInstitutionCreateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'status' => ['nullable', 'in:pending,active,rejected,suspended'],
            'website' => ['nullable', 'string', 'max:200'],
            'email' => ['nullable', 'email', 'max:200'],
            'phone' => ['nullable', 'string', 'max:80'],
            'location' => ['nullable', 'string', 'max:120'],
            'address' => ['nullable', 'string', 'max:200'],
            'motto' => ['nullable', 'string', 'max:160'],
            'description' => ['nullable', 'string', 'max:2000'],
        ];
    }
}
