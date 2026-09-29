<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProfileResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'headline' => $this->headline,
            'bio' => $this->bio,
            'avatar_url' => $this->avatar_url,
            'location' => $this->location,
            'phone' => $this->phone,
            'graduation_year' => $this->graduation_year,
            'program' => $this->program,
            'department' => $this->department,
            'current_company' => $this->current_company,
            'current_role' => $this->current_role,
            'industry' => $this->industry,
            'career_focus' => $this->career_focus,
            'skills' => $this->skills ?? [],
            'interests' => $this->interests ?? [],
            'visibility' => $this->visibility,
            'verification_status' => $this->verification_status,
            'verified_at' => optional($this->verified_at)?->toIso8601String(),
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
