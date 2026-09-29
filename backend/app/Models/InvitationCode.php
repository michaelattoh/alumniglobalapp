<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InvitationCode extends Model
{
    protected $fillable = [
        'code','institution_id','role','expires_at','max_uses','used_count','is_active'
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'expires_at' => 'datetime',
    ];

    public function institution() {
        return $this->belongsTo(Institution::class);
    }
}

