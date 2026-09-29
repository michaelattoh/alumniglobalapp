<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class StudentIdRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'institution_id' => ['required', 'integer', 'exists:institutions,id'],
            'full_name' => ['required', 'string', 'max:180'],
            'email' => ['required', 'email', 'max:190'],
        ];
    }
}
