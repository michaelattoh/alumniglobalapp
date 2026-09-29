<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PostCommentReaction extends Model
{
    protected $fillable = [
        'post_comment_id',
        'user_id',
        'type',
    ];

    public function comment()
    {
        return $this->belongsTo(PostComment::class, 'post_comment_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
