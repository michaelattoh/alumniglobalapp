<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DirectMessage extends Model
{
    protected $fillable = [
        'sender_id',
        'recipient_id',
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
        'read_at',
    ];

    protected function casts(): array
    {
        return [
            'read_at' => 'datetime',
            'is_encrypted' => 'boolean',
        ];
    }

    public function sender()
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function recipient()
    {
        return $this->belongsTo(User::class, 'recipient_id');
    }

    public function replyTo()
    {
        return $this->belongsTo(self::class, 'reply_to_message_id');
    }

    public function reactions()
    {
        return $this->hasMany(DirectMessageReaction::class);
    }
}
