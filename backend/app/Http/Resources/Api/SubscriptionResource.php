<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SubscriptionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user' => new UserLiteResource($this->whenLoaded('user')),
            'institution' => new InstitutionResource($this->whenLoaded('institution')),
            'plan_name' => $this->plan_name,
            'interval' => $this->interval,
            'amount' => $this->amount,
            'currency' => $this->currency,
            'provider' => $this->provider,
            'provider_reference' => $this->provider_reference,
            'status' => $this->status,
            'starts_at' => optional($this->starts_at)?->toIso8601String(),
            'ends_at' => optional($this->ends_at)?->toIso8601String(),
            'cancelled_at' => optional($this->cancelled_at)?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
