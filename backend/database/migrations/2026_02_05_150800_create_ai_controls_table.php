<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('ai_controls', function (Blueprint $table) {
            $table->id();
            $table->boolean('feed_personalization_enabled')->default(true);
            $table->boolean('recommendations_enabled')->default(true);
            $table->unsignedInteger('max_daily_recommendations')->default(100);
            $table->json('guardrails')->nullable();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ai_controls');
    }
};
