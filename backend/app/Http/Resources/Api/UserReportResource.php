<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserReportResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'reporter' => new UserLiteResource($this->whenLoaded('reporter')),
            'reported_user' => new UserLiteResource($this->whenLoaded('reportedUser')),
            'status' => $this->status,
            'reason' => $this->reason,
            'resolved_by' => $this->resolved_by,
            'resolved_at' => optional($this->resolved_at)?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
