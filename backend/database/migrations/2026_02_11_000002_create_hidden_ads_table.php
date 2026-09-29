<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('hidden_ads', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('ad_id')->constrained('ads')->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['user_id', 'ad_id']);
            $table->index(['user_id', 'ad_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('hidden_ads');
    }
};
