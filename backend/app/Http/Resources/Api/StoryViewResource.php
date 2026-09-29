<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class StoryViewResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user' => new UserLiteResource($this->whenLoaded('user')),
            'viewed_at' => optional($this->viewed_at)?->toIso8601String(),
        ];
    }
}
