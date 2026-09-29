<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            if (!Schema::hasColumn('posts', 'is_sponsored')) {
                $table->boolean('is_sponsored')->default(false)->after('is_pinned');
            }
            if (!Schema::hasColumn('posts', 'ad_id')) {
                $table->unsignedBigInteger('ad_id')->nullable()->after('is_sponsored');
                $table->index(['ad_id']);
            }
        });
    }

    public function down(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            if (Schema::hasColumn('posts', 'ad_id')) {
                $table->dropIndex(['ad_id']);
                $table->dropColumn('ad_id');
            }
            if (Schema::hasColumn('posts', 'is_sponsored')) {
                $table->dropColumn('is_sponsored');
            }
        });
    }
};
