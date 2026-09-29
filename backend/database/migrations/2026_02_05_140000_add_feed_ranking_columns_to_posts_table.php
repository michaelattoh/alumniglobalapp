<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            if (!Schema::hasColumn('posts', 'engagement_score')) {
                $table->decimal('engagement_score', 8, 2)->default(0)->after('is_pinned');
            }
            if (!Schema::hasColumn('posts', 'ai_rank_score')) {
                $table->decimal('ai_rank_score', 8, 2)->nullable()->after('engagement_score');
            }
        });
    }

    public function down(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            if (Schema::hasColumn('posts', 'ai_rank_score')) {
                $table->dropColumn('ai_rank_score');
            }
            if (Schema::hasColumn('posts', 'engagement_score')) {
                $table->dropColumn('engagement_score');
            }
        });
    }
};
