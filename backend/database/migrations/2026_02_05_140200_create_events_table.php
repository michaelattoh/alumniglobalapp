<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
            $table->foreignId('institution_id')->nullable()->constrained()->nullOnDelete();
            $table->string('title');
            $table->text('description')->nullable();
            $table->string('event_type')->default('physical'); // physical|virtual
            $table->string('location')->nullable();
            $table->string('meeting_url')->nullable();
            $table->timestamp('starts_at');
            $table->timestamp('ends_at')->nullable();
            $table->unsignedInteger('capacity')->nullable();
            $table->boolean('is_paid')->default(false);
            $table->decimal('price', 10, 2)->nullable();
            $table->string('currency', 3)->nullable();
            $table->string('payment_provider')->nullable();
            $table->string('payment_reference')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['institution_id', 'starts_at']);
            $table->index(['is_active', 'starts_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('events');
    }
};
