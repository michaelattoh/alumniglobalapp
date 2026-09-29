<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AdClick extends Model
{
    protected $fillable = [
        'ad_id',
        'user_id',
        'clicked_at',
    ];

    protected function casts(): array
    {
        return [
            'clicked_at' => 'datetime',
        ];
    }
}
