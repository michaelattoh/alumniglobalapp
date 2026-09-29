<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InstitutionMembershipResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'institution_id' => $this->institution_id,
            'institution' => new InstitutionResource($this->whenLoaded('institution')),
            'user' => new UserLiteResource($this->whenLoaded('user')),
            'role' => $this->role,
            'status' => $this->status,
            'graduation_year' => $this->graduation_year,
            'course' => $this->course,
            'department' => $this->department,
            'approved_by' => $this->approved_by,
            'approved_at' => optional($this->approved_at)?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
