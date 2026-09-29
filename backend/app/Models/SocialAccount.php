<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SocialAccount extends Model
{
    public function user() { return $this->belongsTo(\App\Models\User::class); }

}
