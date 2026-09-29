<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class StoryStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'caption' => ['nullable', 'string', 'max:500'],
            'visibility' => ['required', 'in:public,institution_only'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
            'media' => ['required', 'array', 'min:1', 'max:10'],
            'media.*.type' => ['required', 'in:image,video'],
            'media.*.url' => ['required', 'string', 'max:2048'],
            'media.*.thumbnail_url' => ['nullable', 'string', 'max:2048'],
        ];
    }
}
