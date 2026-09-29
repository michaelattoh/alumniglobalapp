<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SupportTicketMessageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $user = $this->whenLoaded('user');
        $senderRole = 'user';

        if ($user && in_array($user->role, ['super_admin', 'institution_admin', 'support_agent'], true)) {
            $senderRole = 'admin';
        }

        return [
            'id' => $this->id,
            'message' => $this->message,
            'sender_role' => $senderRole,
            'user' => new UserLiteResource($user),
            'created_at' => optional($this->created_at)?->toIso8601String(),
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
