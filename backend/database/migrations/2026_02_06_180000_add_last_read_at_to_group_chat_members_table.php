<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('group_chat_members', function (Blueprint $table) {
            if (!Schema::hasColumn('group_chat_members', 'last_read_at')) {
                $table->timestamp('last_read_at')->nullable()->after('joined_at');
            }
        });
    }

    public function down(): void
    {
        Schema::table('group_chat_members', function (Blueprint $table) {
            if (Schema::hasColumn('group_chat_members', 'last_read_at')) {
                $table->dropColumn('last_read_at');
            }
        });
    }
};
