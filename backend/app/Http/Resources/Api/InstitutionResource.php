<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InstitutionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'status' => $this->status,
            'logo_url' => $this->logo_url,
            'banner_url' => $this->banner_url,
            'website' => $this->website,
            'email' => $this->email,
            'phone' => $this->phone,
            'location' => $this->location,
            'address' => $this->address,
            'motto' => $this->motto,
            'description' => $this->description,
        ];
    }
}
