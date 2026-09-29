<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('scheduled_notification_broadcasts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('created_by')->constrained('users')->cascadeOnDelete();
            $table->string('topic', 40);
            $table->string('title', 120);
            $table->string('type', 60)->nullable();
            $table->text('body')->nullable();
            $table->json('data')->nullable();
            $table->boolean('create_in_app')->default(true);
            $table->timestamp('scheduled_for');
            $table->timestamp('sent_at')->nullable();
            $table->string('status', 20)->default('pending');
            $table->text('error_message')->nullable();
            $table->timestamps();

            $table->index(['status', 'scheduled_for']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('scheduled_notification_broadcasts');
    }
};
