<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('student_ids', function (Blueprint $table) {
            $table->id();
            $table->foreignId('institution_id')->constrained('institutions')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('code', 60)->unique();
            $table->string('full_name', 180)->nullable();
            $table->string('email', 190)->nullable();
            $table->string('status', 20)->default('issued'); // issued|used|revoked
            $table->timestamp('issued_at')->nullable();
            $table->timestamp('used_at')->nullable();
            $table->timestamps();

            $table->index(['institution_id', 'status']);
            $table->index(['user_id', 'institution_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('student_ids');
    }
};
