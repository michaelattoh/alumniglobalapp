<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class InstitutionJoinRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'graduation_year' => ['nullable', 'integer', 'min:1950', 'max:' . (int) now()->format('Y')],
            'course' => ['nullable', 'string', 'max:120'],
            'department' => ['nullable', 'string', 'max:120'],
        ];
    }
}
