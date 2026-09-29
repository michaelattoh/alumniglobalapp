<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class UserLiteResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->when(isset($this->email), $this->email),
            'institution_id' => $this->institution_id,
            'avatar_url' => optional($this->profile)->avatar_url,
        ];
    }
}
