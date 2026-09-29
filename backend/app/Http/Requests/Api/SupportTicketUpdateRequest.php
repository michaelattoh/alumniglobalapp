<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class SupportTicketUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', 'string', 'in:pending,resolved,dismissed'],
            'admin_reply' => ['nullable', 'string', 'max:2000'],
        ];
    }
}
