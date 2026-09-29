<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ProfileUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'headline' => ['nullable', 'string', 'max:120'],
            'bio' => ['nullable', 'string', 'max:2000'],
            'avatar_url' => ['nullable', 'string', 'max:500'],
            'location' => ['nullable', 'string', 'max:120'],
            'phone' => ['nullable', 'string', 'max:30'],

            'graduation_year' => ['nullable', 'integer', 'min:1950', 'max:' . (int) now()->format('Y')],
            'program' => ['nullable', 'string', 'max:120'],
            'department' => ['nullable', 'string', 'max:120'],

            'current_company' => ['nullable', 'string', 'max:120'],
            'current_role' => ['nullable', 'string', 'max:120'],
            'industry' => ['nullable', 'string', 'max:120'],
            'career_focus' => ['nullable', 'string', 'max:120'],

            'skills' => ['nullable', 'array', 'max:50'],
            'skills.*' => ['string', 'max:50'],
            'interests' => ['nullable', 'array', 'max:50'],
            'interests.*' => ['string', 'max:60'],

            'visibility' => ['nullable', Rule::in(['public', 'institution_only'])],
        ];
    }
}
