<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Post extends Model
{
    protected $fillable = [
        'user_id',
        'institution_id',
        'content',
        'visibility',
        'scheduled_at',
        'scheduled_notified_at',
        'is_pinned',
        'is_sponsored',
        'ad_id',
        'engagement_score',
        'ai_rank_score',
        'pinned_at',
        'pinned_by',
        'moderated_at',
        'moderated_by',
    ];

    protected function casts(): array
    {
        return [
            'is_pinned' => 'boolean',
            'is_sponsored' => 'boolean',
            'engagement_score' => 'decimal:2',
            'ai_rank_score' => 'decimal:2',
            'pinned_at' => 'datetime',
            'moderated_at' => 'datetime',
            'scheduled_at' => 'datetime',
            'scheduled_notified_at' => 'datetime',
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
        return $this->hasMany(PostMedia::class)->orderBy('position');
    }

    public function comments()
    {
        return $this->hasMany(PostComment::class);
    }

    public function reactions()
    {
        return $this->hasMany(PostReaction::class);
    }

    public function reports()
    {
        return $this->hasMany(PostReport::class);
    }

    public function saves()
    {
        return $this->hasMany(PostSave::class);
    }

    public function hides()
    {
        return $this->hasMany(PostHide::class);
    }

    public function reposts()
    {
        return $this->hasMany(PostRepost::class);
    }

    public function shares()
    {
        return $this->hasMany(PostShare::class);
    }

    protected $appends = [
        'is_saved',
        'is_liked',
        'user_reaction',
    ];

    public function getIsSavedAttribute(): ?bool
    {
        return $this->attributes['is_saved'] ?? null;
    }

    public function getIsLikedAttribute(): ?bool
    {
        return $this->attributes['is_liked'] ?? null;
    }

    public function getUserReactionAttribute(): ?string
    {
        return $this->attributes['user_reaction'] ?? null;
    }

    public function ad()
    {
        return $this->belongsTo(Ad::class);
    }
}
