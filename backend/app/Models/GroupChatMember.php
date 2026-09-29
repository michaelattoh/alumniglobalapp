<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class GroupChatMember extends Model
{
    protected $fillable = [
        'group_chat_id',
        'user_id',
        'role',
        'joined_at',
    ];

    protected function casts(): array
    {
        return [
            'joined_at' => 'datetime',
            'last_read_at' => 'datetime',
        ];
    }

    public function groupChat()
    {
        return $this->belongsTo(GroupChat::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
