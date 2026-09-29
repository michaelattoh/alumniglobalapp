<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class MeUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'string', 'max:120'],

            'headline' => ['sometimes', 'nullable', 'string', 'max:255'],
            'bio' => ['sometimes', 'nullable', 'string'],
            'avatar_url' => ['sometimes', 'nullable', 'string', 'max:2048'],
            'location' => ['sometimes', 'nullable', 'string', 'max:255'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],

            'graduation_year' => ['sometimes', 'nullable', 'integer', 'min:1950', 'max:' . (int) now()->format('Y')],
            'program' => ['sometimes', 'nullable', 'string', 'max:255'],
            'department' => ['sometimes', 'nullable', 'string', 'max:255'],

            'current_company' => ['sometimes', 'nullable', 'string', 'max:255'],
            'current_role' => ['sometimes', 'nullable', 'string', 'max:255'],
            'industry' => ['sometimes', 'nullable', 'string', 'max:255'],
            'career_focus' => ['sometimes', 'nullable', 'string', 'max:255'],

            'skills' => ['sometimes', 'nullable', 'array'],
            'skills.*' => ['string', 'max:50'],
            'interests' => ['sometimes', 'nullable', 'array'],
            'interests.*' => ['string', 'max:60'],

            'visibility' => ['sometimes', Rule::in(['public', 'institution_only'])],
        ];
    }
}
