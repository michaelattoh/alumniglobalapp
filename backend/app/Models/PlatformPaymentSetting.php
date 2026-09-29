<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PlatformPaymentSetting extends Model
{
    protected $fillable = [
        'stripe_public_key',
        'stripe_secret_key',
        'paystack_public_key',
        'paystack_secret_key',
        'paypal_client_id',
        'paypal_client_secret',
        'flutterwave_public_key',
        'flutterwave_secret_key',
    ];

    protected $casts = [
        'stripe_public_key' => 'encrypted',
        'stripe_secret_key' => 'encrypted',
        'paystack_public_key' => 'encrypted',
        'paystack_secret_key' => 'encrypted',
        'paypal_client_id' => 'encrypted',
        'paypal_client_secret' => 'encrypted',
        'flutterwave_public_key' => 'encrypted',
        'flutterwave_secret_key' => 'encrypted',
    ];
}
