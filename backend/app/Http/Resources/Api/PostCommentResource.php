<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class PostCommentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'post_id' => $this->post_id,
            'user' => new UserLiteResource($this->whenLoaded('user')),
            'content' => $this->content,
            'parent_id' => $this->parent_id,
            'counts' => [
                'likes' => $this->whenCounted('reactions'),
            ],
            'is_liked' => $this->whenAppended('is_liked'),
            'user_reaction' => $this->whenAppended('user_reaction'),
            'created_at' => optional($this->created_at)?->toIso8601String(),
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
