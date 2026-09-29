<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class NotificationPreference extends Model
{
    protected $fillable = [
        'user_id',
        'in_app_enabled',
        'push_enabled',
        'email_enabled',
        'messages_enabled',
        'connections_enabled',
        'events_enabled',
        'ai_personalization_enabled',
    ];

    protected function casts(): array
    {
        return [
            'in_app_enabled' => 'boolean',
            'push_enabled' => 'boolean',
            'email_enabled' => 'boolean',
            'messages_enabled' => 'boolean',
            'connections_enabled' => 'boolean',
            'events_enabled' => 'boolean',
            'ai_personalization_enabled' => 'boolean',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
