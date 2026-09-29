<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->timestamp('budget_alerted_at')->nullable()->after('daily_cap_enabled');
        });
    }

    public function down(): void
    {
        Schema::table('ads', function (Blueprint $table) {
            $table->dropColumn('budget_alerted_at');
        });
    }
};
