<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EventRsvp extends Model
{
    protected $fillable = [
        'event_id',
        'user_id',
        'status',
        'reminder_enabled',
        'reminder_at',
        'reminder_sent_at',
        'responded_at',
    ];

    protected function casts(): array
    {
        return [
            'reminder_enabled' => 'boolean',
            'reminder_at' => 'datetime',
            'reminder_sent_at' => 'datetime',
            'responded_at' => 'datetime',
        ];
    }

    public function event()
    {
        return $this->belongsTo(Event::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
