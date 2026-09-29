<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('institution_payment_settings', function (Blueprint $table) {
            $table->string('paypal_mode')->nullable()->after('paypal_client_secret');
        });
    }

    public function down(): void
    {
        Schema::table('institution_payment_settings', function (Blueprint $table) {
            $table->dropColumn('paypal_mode');
        });
    }
};
