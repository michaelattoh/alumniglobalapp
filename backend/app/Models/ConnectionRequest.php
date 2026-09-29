<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ConnectionRequest extends Model
{
    protected $fillable = [
        'from_user_id',
        'to_user_id',
        'status',
        'message',
        'source',
        'responded_at',
    ];

    protected function casts(): array
    {
        return [
            'responded_at' => 'datetime',
        ];
    }

    public function fromUser()
    {
        return $this->belongsTo(User::class, 'from_user_id');
    }

    public function toUser()
    {
        return $this->belongsTo(User::class, 'to_user_id');
    }
}
