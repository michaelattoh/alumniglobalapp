<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Recommendation extends Model
{
    protected $fillable = [
        'user_id',
        'type',
        'entity_type',
        'entity_id',
        'score',
        'source_model',
        'reason',
        'served_at',
        'clicked_at',
    ];

    protected function casts(): array
    {
        return [
            'score' => 'decimal:4',
            'served_at' => 'datetime',
            'clicked_at' => 'datetime',
        ];
    }
}
