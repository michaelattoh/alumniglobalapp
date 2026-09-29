<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('institution_year_groups', function (Blueprint $table) {
            $table->id();
            $table->foreignId('institution_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->unsignedSmallInteger('graduation_year')->nullable();
            $table->string('description', 280)->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['institution_id', 'graduation_year']);
            $table->unique(['institution_id', 'name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('institution_year_groups');
    }
};
