<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ConnectionRequestResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'from_user' => new UserLiteResource($this->whenLoaded('fromUser')),
            'to_user' => new UserLiteResource($this->whenLoaded('toUser')),
            'status' => $this->status,
            'message' => $this->message,
            'source' => $this->source,
            'responded_at' => optional($this->responded_at)?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
