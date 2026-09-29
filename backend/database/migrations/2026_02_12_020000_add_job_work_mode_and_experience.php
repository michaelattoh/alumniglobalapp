<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('alumni_jobs', function (Blueprint $table) {
            if (!Schema::hasColumn('alumni_jobs', 'work_mode')) {
                $table->string('work_mode', 40)->nullable()->after('location');
            }
            if (!Schema::hasColumn('alumni_jobs', 'experience_level')) {
                $table->string('experience_level', 40)->nullable()->after('salary');
            }
        });
    }

    public function down(): void
    {
        Schema::table('alumni_jobs', function (Blueprint $table) {
            if (Schema::hasColumn('alumni_jobs', 'work_mode')) {
                $table->dropColumn('work_mode');
            }
            if (Schema::hasColumn('alumni_jobs', 'experience_level')) {
                $table->dropColumn('experience_level');
            }
        });
    }
};
