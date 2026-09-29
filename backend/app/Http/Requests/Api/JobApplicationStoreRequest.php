<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class JobApplicationStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user() !== null;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:180'],
            'email' => ['required', 'email', 'max:180'],
            'phone' => ['nullable', 'string', 'max:80'],
            'linkedin_url' => ['nullable', 'url', 'max:255'],
            'resume_url' => ['required', 'string', 'max:255'],
        ];
    }
}
