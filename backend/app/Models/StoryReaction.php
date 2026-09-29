<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StoryReaction extends Model
{
    protected $fillable = [
        'story_id',
        'user_id',
        'emoji',
    ];

    public function story()
    {
        return $this->belongsTo(Story::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
