<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InstitutionYearGroup extends Model
{
    protected $fillable = [
        'institution_id',
        'name',
        'graduation_year',
        'description',
        'created_by',
    ];

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function memberships()
    {
        return $this->hasMany(InstitutionYearGroupMembership::class);
    }
}
