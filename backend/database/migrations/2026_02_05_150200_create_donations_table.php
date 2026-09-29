<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('donations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('campaign_id')->constrained('donation_campaigns')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('transaction_id')->nullable()->constrained('payment_transactions')->nullOnDelete();
            $table->decimal('amount', 12, 2);
            $table->string('currency', 3);
            $table->boolean('is_anonymous')->default(false);
            $table->string('status')->default('pending'); // pending|success|failed|refunded
            $table->text('message')->nullable();
            $table->timestamps();

            $table->index(['campaign_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('donations');
    }
};
