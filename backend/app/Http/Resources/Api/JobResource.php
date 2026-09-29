<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class JobResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'category' => $this->category,
            'company_name' => $this->company_name,
            'location' => $this->location,
            'work_mode' => $this->work_mode,
            'salary' => $this->salary,
            'experience_level' => $this->experience_level,
            'overview' => $this->overview,
            'description' => $this->description,
            'expectations' => $this->expectations,
            'requirements' => $this->requirements,
            'company_overview' => $this->company_overview,
            'is_active' => (bool) $this->is_active,
            'institution' => new InstitutionResource($this->whenLoaded('institution')),
            'published_at' => optional($this->published_at)?->toIso8601String(),
            'created_at' => optional($this->created_at)?->toIso8601String(),
        ];
    }
}
