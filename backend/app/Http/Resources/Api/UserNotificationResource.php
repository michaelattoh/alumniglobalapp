<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserNotificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'title' => $this->title,
            'body' => $this->body,
            'data' => $this->data,
            'is_read' => (bool) $this->is_read,
            'send_push' => (bool) $this->send_push,
            'send_email' => (bool) $this->send_email,
            'read_at' => optional($this->read_at)?->toIso8601String(),
            'sent_at' => optional($this->sent_at)?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
