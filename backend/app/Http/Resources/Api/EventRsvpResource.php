<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EventRsvpResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'event_id' => $this->event_id,
            'user' => new UserLiteResource($this->whenLoaded('user')),
            'status' => $this->status,
            'reminder_enabled' => (bool) $this->reminder_enabled,
            'reminder_at' => optional($this->reminder_at)?->toIso8601String(),
            'reminder_sent_at' => optional($this->reminder_sent_at)?->toIso8601String(),
            'responded_at' => optional($this->responded_at)?->toIso8601String(),
        ];
    }
}
