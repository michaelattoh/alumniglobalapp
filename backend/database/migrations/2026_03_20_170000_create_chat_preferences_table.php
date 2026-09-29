<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('chat_preferences')) {
            return;
        }

        Schema::create('chat_preferences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('chat_key', 120);
            $table->string('wallpaper', 40)->default('default');
            $table->timestamps();

            $table->unique(['user_id', 'chat_key'], 'chat_preferences_user_key_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chat_preferences');
    }
};
