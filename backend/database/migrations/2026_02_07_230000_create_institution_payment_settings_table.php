<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('institution_payment_settings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('institution_id')->constrained()->cascadeOnDelete();
            $table->string('stripe_public_key')->nullable();
            $table->string('stripe_secret_key')->nullable();
            $table->string('paystack_public_key')->nullable();
            $table->string('paystack_secret_key')->nullable();
            $table->string('paypal_client_id')->nullable();
            $table->string('paypal_client_secret')->nullable();
            $table->timestamps();

            $table->unique('institution_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('institution_payment_settings');
    }
};
