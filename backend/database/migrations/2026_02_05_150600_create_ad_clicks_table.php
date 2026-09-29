<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('ad_clicks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('ad_id')->constrained('ads')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamp('clicked_at');
            $table->timestamps();

            $table->index(['ad_id', 'clicked_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ad_clicks');
    }
};
