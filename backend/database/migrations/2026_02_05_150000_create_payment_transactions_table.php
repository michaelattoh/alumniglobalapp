<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('payment_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('institution_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type'); // donation|event_ticket|membership_fee|subscription|refund
            $table->string('provider'); // stripe|paystack|flutterwave
            $table->string('status')->default('pending'); // pending|success|failed|refunded
            $table->decimal('amount', 12, 2);
            $table->string('currency', 3);
            $table->string('reference')->unique();
            $table->string('provider_reference')->nullable();
            $table->foreignId('refunded_transaction_id')->nullable()->constrained('payment_transactions')->nullOnDelete();
            $table->string('receipt_url')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamp('refunded_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
            $table->index(['institution_id', 'created_at']);
            $table->index(['type', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_transactions');
    }
};
