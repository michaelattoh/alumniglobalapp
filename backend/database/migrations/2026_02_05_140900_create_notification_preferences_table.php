<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('notification_preferences', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->boolean('in_app_enabled')->default(true);
            $table->boolean('push_enabled')->default(true);
            $table->boolean('email_enabled')->default(false);
            $table->boolean('messages_enabled')->default(true);
            $table->boolean('connections_enabled')->default(true);
            $table->boolean('events_enabled')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_preferences');
    }
};
