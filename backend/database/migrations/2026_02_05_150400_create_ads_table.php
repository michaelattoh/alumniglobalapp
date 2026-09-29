<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('ads', function (Blueprint $table) {
            $table->id();
            $table->foreignId('advertiser_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('institution_id')->nullable()->constrained()->nullOnDelete();
            $table->string('title');
            $table->text('content')->nullable();
            $table->string('media_url')->nullable();
            $table->string('target_url')->nullable();
            $table->string('placement'); // feed|story|banner
            $table->string('pricing_model')->default('cpc'); // cpc|cpm|flat
            $table->decimal('price', 12, 2)->default(0);
            $table->decimal('budget', 12, 2)->default(0);
            $table->string('currency', 3)->default('GHS');
            $table->unsignedBigInteger('target_institution_id')->nullable();
            $table->string('target_location')->nullable();
            $table->json('target_interests')->nullable();
            $table->string('status')->default('draft'); // draft|active|paused|completed
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->timestamps();

            $table->index(['placement', 'status']);
            $table->index(['target_institution_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('ads');
    }
};
