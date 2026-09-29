<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PaymentTransaction extends Model
{
    protected $fillable = [
        'user_id',
        'institution_id',
        'type',
        'provider',
        'status',
        'amount',
        'currency',
        'reference',
        'provider_reference',
        'refunded_transaction_id',
        'receipt_url',
        'metadata',
        'paid_at',
        'refunded_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'metadata' => 'array',
            'paid_at' => 'datetime',
            'refunded_at' => 'datetime',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }
}
