<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NewsletterSubscriber extends Model
{
    protected $fillable = [
        'email',
        'unsubscribe_token',
        'status',
        'source',
        'ip_address',
        'user_agent',
        'subscribed_at',
        'last_sent_at',
        'unsubscribed_at',
    ];

    protected function casts(): array
    {
        return [
            'subscribed_at' => 'datetime',
            'last_sent_at' => 'datetime',
            'unsubscribed_at' => 'datetime',
        ];
    }
}
