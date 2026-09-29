<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DonationCampaign extends Model
{
    protected $fillable = [
        'institution_id',
        'created_by',
        'title',
        'description',
        'image_url',
        'target_amount',
        'raised_amount',
        'currency',
        'starts_at',
        'ends_at',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'target_amount' => 'decimal:2',
            'raised_amount' => 'decimal:2',
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'is_active' => 'boolean',
        ];
    }

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function donations()
    {
        return $this->hasMany(Donation::class, 'campaign_id');
    }
}
