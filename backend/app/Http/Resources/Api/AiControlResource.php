<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AiControlResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'feed_personalization_enabled' => (bool) $this->feed_personalization_enabled,
            'recommendations_enabled' => (bool) $this->recommendations_enabled,
            'max_daily_recommendations' => (int) $this->max_daily_recommendations,
            'guardrails' => $this->guardrails,
            'updated_by' => $this->updated_by,
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
