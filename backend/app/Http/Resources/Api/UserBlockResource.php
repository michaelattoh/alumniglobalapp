<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserBlockResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'blocker_id' => $this->blocker_id,
            'blocked_id' => $this->blocked_id,
            'reason' => $this->reason,
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
