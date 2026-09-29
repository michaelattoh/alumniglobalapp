<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('newsletter_subscribers', function (Blueprint $table) {
            $table->id();
            $table->string('email', 190)->unique();
            $table->string('status', 30)->default('subscribed');
            $table->string('source', 120)->nullable();
            $table->string('ip_address', 80)->nullable();
            $table->string('user_agent', 255)->nullable();
            $table->timestamp('subscribed_at')->nullable();
            $table->timestamp('last_sent_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('newsletter_subscribers');
    }
};
