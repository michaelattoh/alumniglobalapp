<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('institution_email_settings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('institution_id')->constrained()->cascadeOnDelete();
            $table->string('sender_name')->nullable();
            $table->string('sender_email')->nullable();
            $table->string('smtp_host')->nullable();
            $table->unsignedInteger('smtp_port')->nullable();
            $table->string('smtp_username')->nullable();
            $table->string('smtp_password')->nullable();
            $table->string('smtp_encryption')->nullable();
            $table->boolean('is_enabled')->default(false);
            $table->timestamps();

            $table->unique('institution_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('institution_email_settings');
    }
};
