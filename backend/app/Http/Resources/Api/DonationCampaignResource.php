<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class DonationCampaignResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $institution = $this->whenLoaded('institution');
        $settings = $institution instanceof \App\Models\Institution ? $institution->paymentSetting : null;
        $enabledProviders = [];
        if ($settings) {
            if ($settings->stripe_secret_key) {
                $enabledProviders[] = 'stripe';
            }
            if ($settings->paystack_secret_key) {
                $enabledProviders[] = 'paystack';
            }
            if ($settings->paypal_client_secret) {
                $enabledProviders[] = 'paypal';
            }
            if ($settings->flutterwave_secret_key) {
                $enabledProviders[] = 'flutterwave';
            }
        }

        return [
            'id' => $this->id,
            'title' => $this->title,
            'description' => $this->description,
            'image_url' => $this->image_url,
            'target_amount' => $this->target_amount,
            'raised_amount' => $this->raised_amount,
            'currency' => $this->currency,
            'is_active' => (bool) $this->is_active,
            'starts_at' => optional($this->starts_at)?->toIso8601String(),
            'ends_at' => optional($this->ends_at)?->toIso8601String(),
            'institution' => new InstitutionResource($this->whenLoaded('institution')),
            'creator' => new UserLiteResource($this->whenLoaded('creator')),
            'enabled_providers' => $enabledProviders,
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
