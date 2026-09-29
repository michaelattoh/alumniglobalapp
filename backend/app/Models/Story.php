<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Story extends Model
{
    protected $fillable = [
        'user_id',
        'institution_id',
        'visibility',
        'caption',
        'expires_at',
    ];

    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }

    public function media()
    {
        return $this->hasMany(StoryMedia::class)->orderBy('position');
    }

    public function views()
    {
        return $this->hasMany(StoryView::class);
    }

    public function reactions()
    {
        return $this->hasMany(StoryReaction::class);
    }

    public function reposts()
    {
        return $this->hasMany(StoryRepost::class);
    }

    public function shares()
    {
        return $this->hasMany(StoryShare::class);
    }
}
