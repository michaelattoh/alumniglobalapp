<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('job_applications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('job_id')->constrained('alumni_jobs')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('name', 180);
            $table->string('email', 180);
            $table->string('phone', 80)->nullable();
            $table->string('linkedin_url', 255)->nullable();
            $table->string('resume_url', 255);
            $table->string('status', 40)->default('submitted');
            $table->timestamps();

            $table->index(['job_id', 'status']);
            $table->index(['email']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('job_applications');
    }
};
