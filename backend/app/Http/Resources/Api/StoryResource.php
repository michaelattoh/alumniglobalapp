<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user' => new UserLiteResource($this->whenLoaded('user')),
            'institution_id' => $this->institution_id,
            'visibility' => $this->visibility,
            'caption' => $this->caption,
            'expires_at' => optional($this->expires_at)?->toIso8601String(),
            'media' => StoryMediaResource::collection($this->whenLoaded('media')),
            'view_count' => $this->whenCounted('views'),
            'reaction_count' => $this->whenCounted('reactions'),
            'created_at' => optional($this->created_at)?->toIso8601String(),
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
