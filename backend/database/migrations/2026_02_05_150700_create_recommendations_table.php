<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('recommendations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('type'); // content|event|connection
            $table->string('entity_type'); // post|event|user
            $table->unsignedBigInteger('entity_id');
            $table->decimal('score', 8, 4)->default(0);
            $table->string('source_model')->nullable();
            $table->string('reason')->nullable();
            $table->timestamp('served_at')->nullable();
            $table->timestamp('clicked_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'type']);
            $table->index(['entity_type', 'entity_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('recommendations');
    }
};
