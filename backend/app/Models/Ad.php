<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Ad extends Model
{
    protected $fillable = [
        'advertiser_id',
        'institution_id',
        'title',
        'content',
        'media_url',
        'target_url',
        'placement',
        'pricing_model',
        'objective',
        'price',
        'budget',
        'daily_budget',
        'daily_cap_enabled',
        'budget_alerted_at',
        'currency',
        'target_institution_id',
        'target_location',
        'target_interests',
        'status',
        'starts_at',
        'ends_at',
    ];

    protected function casts(): array
    {
        return [
            'price' => 'decimal:2',
            'budget' => 'decimal:2',
            'daily_budget' => 'decimal:2',
            'daily_cap_enabled' => 'boolean',
            'budget_alerted_at' => 'datetime',
            'target_interests' => 'array',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
        ];
    }

    public function advertiser()
    {
        return $this->belongsTo(User::class, 'advertiser_id');
    }

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }

    public function impressions()
    {
        return $this->hasMany(AdImpression::class);
    }

    public function clicks()
    {
        return $this->hasMany(AdClick::class);
    }
}
