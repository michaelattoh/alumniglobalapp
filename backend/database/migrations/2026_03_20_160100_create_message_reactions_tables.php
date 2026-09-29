<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('direct_message_reactions')) {
            Schema::create('direct_message_reactions', function (Blueprint $table) {
                $table->id();
                $table->foreignId('direct_message_id')->constrained()->cascadeOnDelete();
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                $table->string('emoji', 12);
                $table->timestamps();

                $table->unique(
                    ['direct_message_id', 'user_id'],
                    'dm_reactions_message_user_unique',
                );
            });
        }

        if (!Schema::hasTable('group_chat_message_reactions')) {
            Schema::create('group_chat_message_reactions', function (Blueprint $table) {
                $table->id();
                $table->foreignId('group_chat_message_id')->constrained()->cascadeOnDelete();
                $table->foreignId('user_id')->constrained()->cascadeOnDelete();
                $table->string('emoji', 12);
                $table->timestamps();

                $table->unique(
                    ['group_chat_message_id', 'user_id'],
                    'gcm_reactions_message_user_unique',
                );
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('group_chat_message_reactions');
        Schema::dropIfExists('direct_message_reactions');
    }
};
