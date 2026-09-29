<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class SupportTicketCreateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'subject' => ['required', 'string', 'max:200'],
            'message' => ['required', 'string', 'max:2000'],
            'category' => ['nullable', 'string', 'max:80'],
            'priority' => ['nullable', 'string', 'in:low,normal,high,urgent'],
        ];
    }
}
