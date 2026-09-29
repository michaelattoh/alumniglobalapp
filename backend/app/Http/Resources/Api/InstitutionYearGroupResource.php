<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InstitutionYearGroupResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $viewerMembership = null;
        if ($this->relationLoaded('memberships')) {
            $viewerMembership = $this->memberships->first();
        }

        return [
            'id' => $this->id,
            'institution_id' => $this->institution_id,
            'name' => $this->name,
            'graduation_year' => $this->graduation_year,
            'description' => $this->description,
            'created_by' => $this->created_by,
            'counts' => [
                'approved_members' => (int) ($this->approved_members_count ?? 0),
                'pending_members' => (int) ($this->pending_members_count ?? 0),
            ],
            'viewer_membership' => $viewerMembership
                ? new InstitutionYearGroupMembershipResource($viewerMembership)
                : null,
            'created_at' => optional($this->created_at)?->toIso8601String(),
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
