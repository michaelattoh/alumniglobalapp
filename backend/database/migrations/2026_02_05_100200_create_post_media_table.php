<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('post_media', function (Blueprint $table) {
            $table->id();
            $table->foreignId('post_id')->constrained('posts')->cascadeOnDelete();
            $table->string('type'); // image|video
            $table->string('url');
            $table->string('thumbnail_url')->nullable();
            $table->unsignedInteger('position')->default(0);
            $table->timestamps();

            $table->index(['post_id', 'position']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('post_media');
    }
};
