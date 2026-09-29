<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InstitutionMembership extends Model
{
    protected $fillable = [
        'institution_id',
        'user_id',
        'role',
        'status',
        'graduation_year',
        'course',
        'department',
        'approved_by',
        'approved_at',
    ];

    protected function casts(): array
    {
        return [
            'approved_at' => 'datetime',
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

    public function approver()
    {
        return $this->belongsTo(User::class, 'approved_by');
    }
}
