<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class UserMute extends Model
{
    protected $fillable = [
        'user_id',
        'muted_user_id',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function mutedUser()
    {
        return $this->belongsTo(User::class, 'muted_user_id');
    }
}
