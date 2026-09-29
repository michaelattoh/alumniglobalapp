<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class GroupChatMessageReaction extends Model
{
    protected $fillable = [
        'group_chat_message_id',
        'user_id',
        'emoji',
    ];

    public function message()
    {
        return $this->belongsTo(GroupChatMessage::class, 'group_chat_message_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
