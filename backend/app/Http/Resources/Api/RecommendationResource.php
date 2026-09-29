<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RecommendationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'entity_type' => $this->entity_type,
            'entity_id' => $this->entity_id,
            'score' => $this->score,
            'source_model' => $this->source_model,
            'reason' => $this->reason,
            'served_at' => optional($this->served_at)?->toIso8601String(),
            'clicked_at' => optional($this->clicked_at)?->toIso8601String(),
        ];
    }
}
