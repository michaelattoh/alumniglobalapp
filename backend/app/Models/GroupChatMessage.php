<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class GroupChatMessage extends Model
{
    protected $fillable = [
        'group_chat_id',
        'sender_id',
        'reply_to_message_id',
        'body',
        'is_encrypted',
        'encrypted_payload',
        'encryption_version',
        'encrypted_nonce',
        'sender_key_id',
        'attachment_url',
        'attachment_type',
        'attachment_name',
        'attachment_size',
    ];

    protected function casts(): array
    {
        return [
            'is_encrypted' => 'boolean',
        ];
    }

    public function groupChat()
    {
        return $this->belongsTo(GroupChat::class);
    }

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function replyTo()
    {
        return $this->belongsTo(self::class, 'reply_to_message_id');
    }

    public function reactions()
    {
        return $this->hasMany(GroupChatMessageReaction::class);
    }
}
