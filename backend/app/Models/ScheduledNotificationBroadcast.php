<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ScheduledNotificationBroadcast extends Model
{
    protected $fillable = [
        'created_by',
        'topic',
        'title',
        'body',
        'type',
        'data',
        'create_in_app',
        'scheduled_for',
        'sent_at',
        'status',
        'error_message',
    ];

    protected function casts(): array
    {
        return [
            'data' => 'array',
            'create_in_app' => 'boolean',
            'scheduled_for' => 'datetime',
            'sent_at' => 'datetime',
        ];
    }
}
