<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('stories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('institution_id')->nullable()->constrained()->nullOnDelete();
            $table->string('visibility')->default('public'); // public|institution_only
            $table->text('caption')->nullable();
            $table->timestamp('expires_at');
            $table->timestamps();

            $table->index(['expires_at']);
            $table->index(['institution_id', 'visibility']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('stories');
    }
};
