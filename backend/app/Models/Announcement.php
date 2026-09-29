<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Announcement extends Model
{
    protected $fillable = [
        'created_by',
        'institution_id',
        'title',
        'body',
        'audience',
        'send_email',
        'email_dispatched_at',
        'is_active',
        'starts_at',
        'ends_at',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'send_email' => 'boolean',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'email_dispatched_at' => 'datetime',
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
}
