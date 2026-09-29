<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InstitutionYearGroupMembershipResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'institution_year_group_id' => $this->institution_year_group_id,
            'status' => $this->status,
            'intro' => $this->intro,
            'user' => new UserLiteResource($this->whenLoaded('user')),
            'year_group' => $this->when(
                $this->relationLoaded('yearGroup') && $this->yearGroup,
                fn () => [
                    'id' => $this->yearGroup->id,
                    'name' => $this->yearGroup->name,
                    'graduation_year' => $this->yearGroup->graduation_year,
                ],
            ),
            'approved_by' => $this->approved_by,
            'approved_at' => optional($this->approved_at)?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
