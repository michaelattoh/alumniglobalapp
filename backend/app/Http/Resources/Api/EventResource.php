<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class EventResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $viewerRsvp = null;
        if ($this->relationLoaded('viewerRsvps')) {
            $viewerRsvp = $this->viewerRsvps->first();
        }

        return [
            'id' => $this->id,
            'title' => $this->title,
            'description' => $this->description,
            'event_type' => $this->event_type,
            'location' => $this->location,
            'meeting_url' => $this->meeting_url,
            'starts_at' => optional($this->starts_at)?->toIso8601String(),
            'ends_at' => optional($this->ends_at)?->toIso8601String(),
            'capacity' => $this->capacity,
            'is_paid' => (bool) $this->is_paid,
            'price' => $this->price,
            'currency' => $this->currency,
            'payment_provider' => $this->payment_provider,
            'payment_reference' => $this->payment_reference,
            'is_active' => (bool) $this->is_active,
            'institution' => new InstitutionResource($this->whenLoaded('institution')),
            'creator' => new UserLiteResource($this->whenLoaded('creator')),
            'going_count' => $this->when(isset($this->going_count), (int) $this->going_count),
            'rsvp_status' => $viewerRsvp?->status,
            'reminder_enabled' => $viewerRsvp ? (bool) $viewerRsvp->reminder_enabled : null,
            'reminder_at' => $viewerRsvp?->reminder_at?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
