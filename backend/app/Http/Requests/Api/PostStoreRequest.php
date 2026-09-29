<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class PostStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'content' => ['nullable', 'string', 'max:5000'],
            'visibility' => ['required', 'in:public,institution_only'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'scheduled_at' => ['nullable', 'date'],
            'mentions' => ['nullable', 'array', 'max:20'],
            'mentions.*' => ['integer', 'distinct', 'exists:users,id'],
            'media' => ['nullable', 'array', 'max:10'],
            'media.*.type' => ['required_with:media', 'in:image,video'],
            'media.*.url' => ['required_with:media', 'string', 'max:2048'],
            'media.*.thumbnail_url' => ['nullable', 'string', 'max:2048'],
        ];
    }
}
