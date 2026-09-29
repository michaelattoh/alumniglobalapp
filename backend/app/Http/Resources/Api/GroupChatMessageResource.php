<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use App\Models\GroupChatMember;

class GroupChatMessageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $readCount = GroupChatMember::where('group_chat_id', $this->group_chat_id)
            ->where('user_id', '!=', $this->sender_id)
            ->whereNotNull('last_read_at')
            ->where('last_read_at', '>=', $this->created_at)
            ->count();

        return [
            'id' => $this->id,
            'reply_to_message_id' => $this->reply_to_message_id,
            'reply_to' => $this->when(
                $this->relationLoaded('replyTo') && $this->replyTo,
                fn () => [
                    'id' => $this->replyTo->id,
                    'body' => $this->replyTo->body,
                    'attachment_type' => $this->replyTo->attachment_type,
                    'sender' => new UserLiteResource($this->replyTo->relationLoaded('sender') ? $this->replyTo->sender : null),
                ]
            ),
            'body' => $this->body,
            'is_encrypted' => (bool) $this->is_encrypted,
            'encrypted_payload' => $this->encrypted_payload,
            'encryption_version' => $this->encryption_version,
            'encrypted_nonce' => $this->encrypted_nonce,
            'sender_key_id' => $this->sender_key_id,
            'attachment_url' => $this->attachment_url,
            'attachment_type' => $this->attachment_type,
            'attachment_name' => $this->attachment_name,
            'attachment_size' => $this->attachment_size,
            'sender' => new UserLiteResource($this->whenLoaded('sender')),
            'reactions' => $this->when(
                $this->relationLoaded('reactions'),
                fn () => $this->reactions->map(fn ($reaction) => [
                    'id' => $reaction->id,
                    'emoji' => $reaction->emoji,
                    'user_id' => $reaction->user_id,
                    'user_name' => $reaction->relationLoaded('user') ? $reaction->user?->name : null,
                ])->values()
            ),
            'read_by_count' => $readCount,
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
