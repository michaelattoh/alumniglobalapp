<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('donation_campaigns', function (Blueprint $table) {
            $table->id();
            $table->foreignId('institution_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
            $table->string('title');
            $table->text('description')->nullable();
            $table->decimal('target_amount', 12, 2)->default(0);
            $table->decimal('raised_amount', 12, 2)->default(0);
            $table->string('currency', 3)->default('GHS');
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('ends_at')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['institution_id', 'is_active']);
            $table->index(['is_active', 'ends_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('donation_campaigns');
    }
};
