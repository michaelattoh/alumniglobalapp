<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class GroupChatCreateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:120'],
            'member_ids' => ['required', 'array', 'min:1', 'max:50'],
            'member_ids.*' => ['integer', 'exists:users,id'],
        ];
    }
}
