<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->string('objective')->default('traffic')->after('pricing_model');
            $table->decimal('daily_budget', 12, 2)->nullable()->after('budget');
            $table->boolean('daily_cap_enabled')->default(false)->after('daily_budget');
        });
    }

    public function down(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->dropColumn(['objective', 'daily_budget', 'daily_cap_enabled']);
        });
    }
};
