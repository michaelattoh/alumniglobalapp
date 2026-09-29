<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PostComment extends Model
{
    protected $fillable = [
        'post_id',
        'user_id',
        'content',
        'parent_id',
    ];

    protected $appends = [
        'is_liked',
        'user_reaction',
    ];

    public function post()
    {
        return $this->belongsTo(Post::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function parent()
    {
        return $this->belongsTo(PostComment::class, 'parent_id');
    }

    public function reactions()
    {
        return $this->hasMany(PostCommentReaction::class);
    }

    public function getIsLikedAttribute(): ?bool
    {
        return $this->attributes['is_liked'] ?? null;
    }

    public function getUserReactionAttribute(): ?string
    {
        return $this->attributes['user_reaction'] ?? null;
    }
}
