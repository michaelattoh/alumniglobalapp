<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE institution_payment_settings MODIFY stripe_public_key TEXT NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY stripe_secret_key TEXT NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY paystack_public_key TEXT NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY paystack_secret_key TEXT NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY paypal_client_id TEXT NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY paypal_client_secret TEXT NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY flutterwave_public_key TEXT NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY flutterwave_secret_key TEXT NULL');

        DB::statement('ALTER TABLE platform_payment_settings MODIFY stripe_public_key TEXT NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY stripe_secret_key TEXT NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY paystack_public_key TEXT NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY paystack_secret_key TEXT NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY paypal_client_id TEXT NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY paypal_client_secret TEXT NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY flutterwave_public_key TEXT NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY flutterwave_secret_key TEXT NULL');
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE institution_payment_settings MODIFY stripe_public_key VARCHAR(255) NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY stripe_secret_key VARCHAR(255) NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY paystack_public_key VARCHAR(255) NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY paystack_secret_key VARCHAR(255) NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY paypal_client_id VARCHAR(255) NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY paypal_client_secret VARCHAR(255) NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY flutterwave_public_key VARCHAR(255) NULL');
        DB::statement('ALTER TABLE institution_payment_settings MODIFY flutterwave_secret_key VARCHAR(255) NULL');

        DB::statement('ALTER TABLE platform_payment_settings MODIFY stripe_public_key VARCHAR(255) NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY stripe_secret_key VARCHAR(255) NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY paystack_public_key VARCHAR(255) NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY paystack_secret_key VARCHAR(255) NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY paypal_client_id VARCHAR(255) NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY paypal_client_secret VARCHAR(255) NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY flutterwave_public_key VARCHAR(255) NULL');
        DB::statement('ALTER TABLE platform_payment_settings MODIFY flutterwave_secret_key VARCHAR(255) NULL');
    }
};
