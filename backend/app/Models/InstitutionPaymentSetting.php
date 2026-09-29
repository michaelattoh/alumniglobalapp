<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class InstitutionPaymentSetting extends Model
{
    protected $fillable = [
        'institution_id',
        'stripe_public_key',
        'stripe_secret_key',
        'paystack_public_key',
        'paystack_secret_key',
        'paypal_client_id',
        'paypal_client_secret',
        'paypal_mode',
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

    public function institution()
    {
        return $this->belongsTo(Institution::class);
    }

    public function hasProvider(string $provider): bool
    {
        $provider = strtolower($provider);
        if ($provider === 'momo') {
            $provider = 'paystack';
        }

        return match ($provider) {
            'stripe' => (bool) $this->stripe_secret_key,
            'paystack' => (bool) $this->paystack_secret_key,
            'paypal' => (bool) $this->paypal_client_secret,
            'flutterwave' => (bool) $this->flutterwave_secret_key,
            default => false,
        };
    }
}
