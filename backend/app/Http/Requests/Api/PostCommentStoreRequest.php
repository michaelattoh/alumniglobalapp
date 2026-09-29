<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class PostCommentStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'content' => ['required', 'string', 'max:1000'],
            'parent_id' => ['nullable', 'integer', 'exists:post_comments,id'],
            'mentions' => ['nullable', 'array', 'max:10'],
            'mentions.*' => ['integer', 'distinct', 'exists:users,id'],
        ];
    }
}
