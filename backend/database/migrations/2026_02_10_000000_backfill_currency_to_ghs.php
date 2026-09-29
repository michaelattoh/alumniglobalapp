<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('donation_campaigns')->where('currency', 'USD')->update(['currency' => 'GHS']);
        DB::table('ads')->where('currency', 'USD')->update(['currency' => 'GHS']);
        DB::table('payment_transactions')->where('currency', 'USD')->update(['currency' => 'GHS']);
        DB::table('subscriptions')->where('currency', 'USD')->update(['currency' => 'GHS']);
        DB::table('system_settings')->where('key', 'default_currency')->update(['value' => json_encode('GHS')]);
    }

    public function down(): void
    {
        DB::table('donation_campaigns')->where('currency', 'GHS')->update(['currency' => 'USD']);
        DB::table('ads')->where('currency', 'GHS')->update(['currency' => 'USD']);
        DB::table('payment_transactions')->where('currency', 'GHS')->update(['currency' => 'USD']);
        DB::table('subscriptions')->where('currency', 'GHS')->update(['currency' => 'USD']);
        DB::table('system_settings')->where('key', 'default_currency')->update(['value' => json_encode('USD')]);
    }
};
