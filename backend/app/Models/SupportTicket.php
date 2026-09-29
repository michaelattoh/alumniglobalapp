<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SupportTicket extends Model
{
    protected $fillable = [
        'reference',
        'user_id',
        'institution_id',
        'subject',
        'message',
        'category',
        'priority',
        'status',
        'admin_reply',
        'resolved_by',
        'resolved_at',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }

    public function messages()
    {
        return $this->hasMany(SupportTicketMessage::class)->orderBy('created_at');
    }
}
