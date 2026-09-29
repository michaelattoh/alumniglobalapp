<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Job extends Model
{
    protected $table = 'alumni_jobs';

    protected $fillable = [
        'institution_id',
        'title',
        'category',
        'company_name',
        'location',
        'work_mode',
        'salary',
        'experience_level',
        'overview',
        'description',
        'expectations',
        'requirements',
        'company_overview',
        'is_active',
        'published_at',
    ];

    protected function casts(): array
    {
        return [
            'expectations' => 'array',
            'requirements' => 'array',
            'is_active' => 'boolean',
            'published_at' => 'datetime',
        ];
    }

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }

    public function applications()
    {
        return $this->hasMany(JobApplication::class);
    }
}
