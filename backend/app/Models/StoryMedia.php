<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StoryMedia extends Model
{
    protected $table = 'story_media';

    protected $fillable = [
        'story_id',
        'type',
        'url',
        'thumbnail_url',
        'position',
    ];

    public function story()
    {
        return $this->belongsTo(Story::class);
    }
}
