<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class GroupChatResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'creator' => new UserLiteResource($this->whenLoaded('creator')),
            'members_count' => $this->whenCounted('members', function () {
                return $this->members_count;
            }),
            'is_active' => (bool) $this->is_active,
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
