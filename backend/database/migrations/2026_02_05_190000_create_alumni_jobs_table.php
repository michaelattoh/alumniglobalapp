<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (Schema::hasTable('alumni_jobs')) {
            return;
        }

        Schema::create('alumni_jobs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('institution_id')->nullable()->constrained('institutions')->nullOnDelete();
            $table->string('title', 180);
            $table->string('category', 80)->nullable();
            $table->string('company_name', 180)->nullable();
            $table->string('location', 120)->nullable();
            $table->string('salary', 120)->nullable();
            $table->text('overview')->nullable();
            $table->longText('description')->nullable();
            $table->json('expectations')->nullable();
            $table->json('requirements')->nullable();
            $table->text('company_overview')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamp('published_at')->nullable();
            $table->timestamps();

            $table->index(['institution_id', 'is_active']);
            $table->index(['category', 'published_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('alumni_jobs');
    }
};
