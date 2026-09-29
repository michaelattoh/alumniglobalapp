<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('direct_messages', function (Blueprint $table) {
            $table->foreignId('reply_to_message_id')
                ->nullable()
                ->after('recipient_id')
                ->constrained('direct_messages')
                ->nullOnDelete();
        });

        Schema::table('group_chat_messages', function (Blueprint $table) {
            $table->foreignId('reply_to_message_id')
                ->nullable()
                ->after('sender_id')
                ->constrained('group_chat_messages')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('group_chat_messages', function (Blueprint $table) {
            $table->dropConstrainedForeignId('reply_to_message_id');
        });

        Schema::table('direct_messages', function (Blueprint $table) {
            $table->dropConstrainedForeignId('reply_to_message_id');
        });
    }
};
