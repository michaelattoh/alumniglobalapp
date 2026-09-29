<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('platform_payment_settings', function (Blueprint $table) {
            $table->id();
            $table->string('stripe_public_key')->nullable();
            $table->string('stripe_secret_key')->nullable();
            $table->string('paystack_public_key')->nullable();
            $table->string('paystack_secret_key')->nullable();
            $table->string('paypal_client_id')->nullable();
            $table->string('paypal_client_secret')->nullable();
            $table->string('flutterwave_public_key')->nullable();
            $table->string('flutterwave_secret_key')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('platform_payment_settings');
    }
};
