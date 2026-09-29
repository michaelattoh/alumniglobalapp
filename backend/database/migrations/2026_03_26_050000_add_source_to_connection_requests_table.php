<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('connection_requests')) {
            return;
        }

        Schema::table('connection_requests', function (Blueprint $table) {
            if (!Schema::hasColumn('connection_requests', 'source')) {
                $table->string('source', 40)->nullable()->after('message');
            }
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('connection_requests')) {
            return;
        }

        Schema::table('connection_requests', function (Blueprint $table) {
            if (Schema::hasColumn('connection_requests', 'source')) {
                $table->dropColumn('source');
            }
        });
    }
};
