<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('story_media', function (Blueprint $table) {
            $table->id();
            $table->foreignId('story_id')->constrained('stories')->cascadeOnDelete();
            $table->string('type'); // image|video
            $table->string('url');
            $table->string('thumbnail_url')->nullable();
            $table->unsignedInteger('position')->default(0);
            $table->timestamps();

            $table->index(['story_id', 'position']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('story_media');
    }
};
