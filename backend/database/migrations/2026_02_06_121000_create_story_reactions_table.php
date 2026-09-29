<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('story_reactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('story_id')->constrained('stories')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('emoji', 12);
            $table->timestamps();

            $table->unique(['story_id', 'user_id']);
            $table->index(['story_id', 'emoji']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('story_reactions');
    }
};
