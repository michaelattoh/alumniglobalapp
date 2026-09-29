<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('announcements', function (Blueprint $table) {
            $table->boolean('send_email')->default(false)->after('audience');
            $table->timestamp('email_dispatched_at')->nullable()->after('send_email');
        });
    }

    public function down(): void
    {
        Schema::table('announcements', function (Blueprint $table) {
            $table->dropColumn(['send_email', 'email_dispatched_at']);
        });
    }
};
