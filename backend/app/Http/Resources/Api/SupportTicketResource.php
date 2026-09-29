<?php

namespace App\Http\Resources\Api;

use Illuminate\Support\Collection;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SupportTicketResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'reference' => $this->reference,
            'subject' => $this->subject,
            'message' => $this->message,
            'category' => $this->category,
            'priority' => $this->priority,
            'status' => $this->status,
            'admin_reply' => $this->admin_reply,
            'user' => new UserLiteResource($this->whenLoaded('user')),
            'institution' => new InstitutionResource($this->whenLoaded('institution')),
            'messages' => $this->resolveMessages(),
            'resolved_by' => $this->resolved_by,
            'resolved_at' => optional($this->resolved_at)?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }

    private function resolveMessages(): array
    {
        if ($this->relationLoaded('messages') && $this->messages->isNotEmpty()) {
            return SupportTicketMessageResource::collection($this->messages)->resolve();
        }

        $messages = new Collection();

        if (!empty($this->message)) {
            $messages->push([
                'id' => 'legacy-user-' . $this->id,
                'message' => $this->message,
                'sender_role' => 'user',
                'user' => $this->relationLoaded('user') && $this->user
                    ? (new UserLiteResource($this->user))->resolve()
                    : null,
                'created_at' => optional($this->created_at)?->toIso8601String(),
                'updated_at' => optional($this->created_at)?->toIso8601String(),
            ]);
        }

        if (!empty($this->admin_reply)) {
            $messages->push([
                'id' => 'legacy-admin-' . $this->id,
                'message' => $this->admin_reply,
                'sender_role' => 'admin',
                'user' => null,
                'created_at' => optional($this->updated_at)?->toIso8601String(),
                'updated_at' => optional($this->updated_at)?->toIso8601String(),
            ]);
        }

        return $messages->values()->all();
    }
}
