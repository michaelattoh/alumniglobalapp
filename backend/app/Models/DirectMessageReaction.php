<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DirectMessageReaction extends Model
{
    protected $fillable = [
        'direct_message_id',
        'user_id',
        'emoji',
    ];

    public function message()
    {
        return $this->belongsTo(DirectMessage::class, 'direct_message_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
