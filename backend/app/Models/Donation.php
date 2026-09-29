<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Donation extends Model
{
    protected $fillable = [
        'campaign_id',
        'user_id',
        'transaction_id',
        'amount',
        'currency',
        'is_anonymous',
        'status',
        'message',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'is_anonymous' => 'boolean',
        ];
    }

    public function campaign()
    {
        return $this->belongsTo(DonationCampaign::class, 'campaign_id');
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function transaction()
    {
        return $this->belongsTo(PaymentTransaction::class, 'transaction_id');
    }
}
