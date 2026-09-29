<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AdImpression extends Model
{
    protected $fillable = [
        'ad_id',
        'user_id',
        'placement',
        'viewed_at',
    ];

    protected function casts(): array
    {
        return [
            'viewed_at' => 'datetime',
        ];
    }
}
