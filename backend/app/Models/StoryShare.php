<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StoryShare extends Model
{
    protected $fillable = [
        'story_id',
        'user_id',
        'channel',
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
