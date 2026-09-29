<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Event extends Model
{
    protected $fillable = [
        'created_by',
        'institution_id',
        'title',
        'description',
        'event_type',
        'location',
        'meeting_url',
        'starts_at',
        'ends_at',
        'capacity',
        'is_paid',
        'price',
        'currency',
        'payment_provider',
        'payment_reference',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'is_paid' => 'boolean',
            'is_active' => 'boolean',
            'price' => 'decimal:2',
        ];
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }

    public function rsvps()
    {
        return $this->hasMany(EventRsvp::class);
    }

    public function viewerRsvps()
    {
        return $this->hasMany(EventRsvp::class);
    }
}
