<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class GroupChatMemberResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'role' => $this->role,
            'joined_at' => optional($this->joined_at)?->toIso8601String(),
            'user' => new UserLiteResource($this->whenLoaded('user')),
        ];
    }
}
