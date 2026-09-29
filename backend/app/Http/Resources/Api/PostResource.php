<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PostResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user' => new UserLiteResource($this->whenLoaded('user')),
            'institution_id' => $this->institution_id,
            'content' => $this->content,
            'visibility' => $this->visibility,
            'scheduled_at' => optional($this->scheduled_at)?->toIso8601String(),
            'is_pinned' => (bool) $this->is_pinned,
            'pinned_at' => optional($this->pinned_at)?->toIso8601String(),
            'media' => PostMediaResource::collection($this->whenLoaded('media')),
            'counts' => [
                'comments' => $this->whenCounted('comments'),
                'reactions' => $this->whenCounted('reactions'),
                'reports' => $this->whenCounted('reports'),
            ],
            'is_saved' => $this->whenAppended('is_saved'),
            'is_liked' => $this->whenAppended('is_liked'),
            'user_reaction' => $this->whenAppended('user_reaction'),
            'created_at' => optional($this->created_at)?->toIso8601String(),
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
