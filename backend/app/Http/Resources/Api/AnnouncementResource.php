<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AnnouncementResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'body' => $this->body,
            'audience' => $this->audience,
            'institution' => new InstitutionResource($this->whenLoaded('institution')),
            'creator' => new UserLiteResource($this->whenLoaded('creator')),
            'is_active' => (bool) $this->is_active,
            'send_email' => (bool) $this->send_email,
            'email_dispatched_at' => optional($this->email_dispatched_at)?->toIso8601String(),
            'starts_at' => optional($this->starts_at)?->toIso8601String(),
            'ends_at' => optional($this->ends_at)?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
