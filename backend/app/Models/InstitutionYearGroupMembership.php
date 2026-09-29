<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InstitutionYearGroupMembership extends Model
{
    protected $fillable = [
        'institution_year_group_id',
        'user_id',
        'status',
        'intro',
        'approved_by',
        'approved_at',
    ];

    protected function casts(): array
    {
        return [
            'approved_at' => 'datetime',
        ];
    }

    public function yearGroup()
    {
        return $this->belongsTo(InstitutionYearGroup::class, 'institution_year_group_id');
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
