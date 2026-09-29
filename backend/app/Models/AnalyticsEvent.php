<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AnalyticsEvent extends Model
{
    protected $fillable = [
        'user_id',
        'institution_id',
        'event_type',
        'entity_type',
        'entity_id',
        'value',
        'metadata',
        'occurred_at',
    ];

    protected function casts(): array
    {
        return [
            'value' => 'decimal:2',
            'metadata' => 'array',
            'occurred_at' => 'datetime',
        ];
    }
}
