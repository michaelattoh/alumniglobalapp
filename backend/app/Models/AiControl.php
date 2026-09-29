<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AiControl extends Model
{
    protected $fillable = [
        'feed_personalization_enabled',
        'recommendations_enabled',
        'max_daily_recommendations',
        'guardrails',
        'updated_by',
    ];

    protected function casts(): array
    {
        return [
            'feed_personalization_enabled' => 'boolean',
            'recommendations_enabled' => 'boolean',
            'max_daily_recommendations' => 'integer',
            'guardrails' => 'array',
        ];
    }
}
