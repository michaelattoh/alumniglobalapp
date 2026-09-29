<?php

namespace App\Http\Resources\Api;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class SystemSettingResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'key' => $this->key,
            'value' => $this->value,
            'updated_by' => $this->updated_by,
            'updated_at' => optional($this->updated_at)?->toIso8601String(),
        ];
    }
}
