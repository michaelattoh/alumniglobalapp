<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class InstitutionYearGroupStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:120'],
            'graduation_year' => ['nullable', 'integer', 'min:1950', 'max:' . (int) now()->format('Y')],
            'description' => ['nullable', 'string', 'max:280'],
        ];
    }
}
