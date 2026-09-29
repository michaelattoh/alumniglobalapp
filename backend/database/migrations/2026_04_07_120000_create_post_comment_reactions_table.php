<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('post_comment_reactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('post_comment_id')->constrained('post_comments')->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('type')->default('like');
            $table->timestamps();

            $table->unique(['post_comment_id', 'user_id', 'type']);
            $table->index(['post_comment_id', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('post_comment_reactions');
    }
};
