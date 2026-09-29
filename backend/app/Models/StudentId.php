<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class StudentId extends Model
{
    protected $fillable = [
        'institution_id',
        'user_id',
        'code',
        'full_name',
        'email',
        'status',
        'issued_at',
        'used_at',
    ];

    protected function casts(): array
    {
        return [
            'issued_at' => 'datetime',
            'used_at' => 'datetime',
        ];
    }

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
