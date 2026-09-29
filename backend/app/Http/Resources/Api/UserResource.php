<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'role' => $this->role,
            'status' => $this->status,
            'institution_id' => $this->institution_id,
            'institution' => new InstitutionResource($this->whenLoaded('institution')),
            'profile' => new ProfileResource($this->whenLoaded('profile')),
        ];
    }
}
