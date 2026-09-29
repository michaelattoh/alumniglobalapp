<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class AdServeRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'placement' => ['required', 'in:feed,story,banner'],
            'institution_id' => ['nullable', 'integer'],
            'location' => ['nullable', 'string', 'max:120'],
            'interests' => ['nullable', 'array', 'max:20'],
            'interests.*' => ['string', 'max:60'],
        ];
    }
}
