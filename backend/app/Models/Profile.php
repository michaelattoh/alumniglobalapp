<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Profile extends Model
{

    protected $fillable = [
    'headline',
    'bio',
    'avatar_url',
    'location',
    'phone',
    'graduation_year',
    'program',
    'department',
    'current_company',
    'current_role',
    'industry',
    'career_focus',
    'skills',
    'interests',
    'visibility',
    'verification_status',
    'verified_by',
    'verified_at',
    ];




    protected function casts(): array
    {
        return [
            'skills' => 'array',
            'interests' => 'array',
            'verified_at' => 'datetime',
        ];
    }


    public function user() { return $this->belongsTo(User::class); }
    public function verifier() { return $this->belongsTo(User::class, 'verified_by'); }

}
