<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DonationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'amount' => $this->amount,
            'currency' => $this->currency,
            'is_anonymous' => (bool) $this->is_anonymous,
            'status' => $this->status,
            'message' => $this->message,
            'campaign' => new DonationCampaignResource($this->whenLoaded('campaign')),
            'transaction' => new PaymentTransactionResource($this->whenLoaded('transaction')),
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
