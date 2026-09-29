<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('institution_payment_settings', function (Blueprint $table) {
            $table->string('flutterwave_public_key')->nullable()->after('paypal_client_secret');
            $table->string('flutterwave_secret_key')->nullable()->after('flutterwave_public_key');
        });
    }

    public function down(): void
    {
        Schema::table('institution_payment_settings', function (Blueprint $table) {
            $table->dropColumn(['flutterwave_public_key', 'flutterwave_secret_key']);
        });
    }
};
