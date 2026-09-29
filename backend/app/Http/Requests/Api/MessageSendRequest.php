<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class MessageSendRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'body' => ['nullable', 'string', 'max:4000', 'required_without_all:attachment_url,encrypted_payload'],
            'reply_to_message_id' => ['nullable', 'integer', 'exists:direct_messages,id'],
            'attachment_url' => ['nullable', 'string', 'max:2048', 'required_without_all:body,encrypted_payload'],
            'attachment_type' => ['nullable', 'string', 'in:image,video,document,audio'],
            'attachment_name' => ['nullable', 'string', 'max:255'],
            'attachment_size' => ['nullable', 'integer', 'min:0'],
            'is_encrypted' => ['nullable', 'boolean'],
            'encrypted_payload' => ['nullable', 'string', 'required_without_all:body,attachment_url'],
            'encryption_version' => ['nullable', 'string', 'max:30', 'required_with:encrypted_payload'],
            'encrypted_nonce' => ['nullable', 'string', 'max:255', 'required_with:encrypted_payload'],
            'sender_key_id' => ['nullable', 'string', 'max:255'],
        ];
    }
}
