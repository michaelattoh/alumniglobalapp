<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('group_chat_members', function (Blueprint $table) {
            $table->id();
            $table->foreignId('group_chat_id')->constrained('group_chats')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('role')->default('member'); // member|admin
            $table->timestamp('joined_at')->nullable();
            $table->timestamps();

            $table->unique(['group_chat_id', 'user_id']);
            $table->index(['user_id', 'group_chat_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('group_chat_members');
    }
};
