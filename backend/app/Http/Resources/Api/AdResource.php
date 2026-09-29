<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AdResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $impressions = isset($this->impressions_count) ? (int) $this->impressions_count : 0;
        $clicks = isset($this->clicks_count) ? (int) $this->clicks_count : 0;
        $ctr = $impressions > 0 ? round(($clicks / $impressions) * 100, 2) : 0;
        $price = (float) ($this->price ?? 0);
        $spend = 0;

        if ($this->pricing_model === 'cpc') {
            $spend = $clicks * $price;
        } elseif ($this->pricing_model === 'cpm') {
            $spend = ($impressions / 1000) * $price;
        } elseif ($this->pricing_model === 'flat') {
            $spend = ($impressions > 0 || $clicks > 0) ? $price : 0;
        }

        $budgetRemaining = null;
        if ($this->budget !== null) {
            $budgetRemaining = max(0, (float) $this->budget - $spend);
        }

        return [
            'id' => $this->id,
            'advertiser' => new UserLiteResource($this->whenLoaded('advertiser')),
            'institution' => new InstitutionResource($this->whenLoaded('institution')),
            'title' => $this->title,
            'content' => $this->content,
            'media_url' => $this->media_url,
            'target_url' => $this->target_url,
            'placement' => $this->placement,
            'pricing_model' => $this->pricing_model,
            'objective' => $this->objective,
            'price' => $this->price,
            'budget' => $this->budget,
            'daily_budget' => $this->daily_budget,
            'daily_cap_enabled' => (bool) $this->daily_cap_enabled,
            'currency' => $this->currency,
            'target_institution_id' => $this->target_institution_id,
            'target_location' => $this->target_location,
            'target_interests' => $this->target_interests,
            'status' => $this->status,
            'starts_at' => optional($this->starts_at)?->toIso8601String(),
            'ends_at' => optional($this->ends_at)?->toIso8601String(),
            'metrics' => [
                'impressions' => $this->when(isset($this->impressions_count), $impressions),
                'clicks' => $this->when(isset($this->clicks_count), $clicks),
                'ctr_percent' => $this->when(isset($this->impressions_count), $ctr),
                'spend' => $this->when(isset($this->impressions_count), round($spend, 2)),
                'budget_remaining' => $this->when(isset($this->impressions_count), $budgetRemaining),
            ],
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
