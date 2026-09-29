<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AuditLogResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'actor' => new UserLiteResource($this->whenLoaded('actor')),
            'action' => $this->action,
            'entity_type' => $this->entity_type,
            'entity_id' => $this->entity_id,
            'metadata' => $this->metadata,
            'ip' => $this->ip,
            'user_agent' => $this->user_agent,
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
