<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class NotificationPreferenceResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'user_id' => $this->user_id,
            'in_app_enabled' => (bool) $this->in_app_enabled,
            'push_enabled' => (bool) $this->push_enabled,
            'email_enabled' => (bool) $this->email_enabled,
            'messages_enabled' => (bool) $this->messages_enabled,
            'connections_enabled' => (bool) $this->connections_enabled,
            'events_enabled' => (bool) $this->events_enabled,
            'ai_personalization_enabled' => (bool) $this->ai_personalization_enabled,
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
