<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class GroupChat extends Model
{
    protected $fillable = [
        'created_by',
        'name',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function members()
    {
        return $this->hasMany(GroupChatMember::class);
    }

    public function messages()
    {
        return $this->hasMany(GroupChatMessage::class);
    }
}
