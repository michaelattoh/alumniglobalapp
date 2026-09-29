<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('event_rsvps', function (Blueprint $table) {
            $table->timestamp('reminder_sent_at')->nullable()->after('reminder_at');
            $table->index(['reminder_enabled', 'reminder_at'], 'event_rsvps_reminder_idx');
        });
    }

    public function down(): void
    {
        Schema::table('event_rsvps', function (Blueprint $table) {
            $table->dropIndex('event_rsvps_reminder_idx');
            $table->dropColumn('reminder_sent_at');
        });
    }
};
