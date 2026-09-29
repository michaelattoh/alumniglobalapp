<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('group_chat_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('group_chat_id')->constrained('group_chats')->cascadeOnDelete();
            $table->foreignId('sender_id')->constrained('users')->cascadeOnDelete();
            $table->text('body');
            $table->timestamps();

            $table->index(['group_chat_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('group_chat_messages');
    }
};
