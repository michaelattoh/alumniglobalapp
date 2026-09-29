<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
        
            $table->string('headline')->nullable();
            $table->text('bio')->nullable();
            $table->string('avatar_url')->nullable();
            $table->string('location')->nullable();
            $table->string('phone')->nullable();
        
            $table->unsignedSmallInteger('graduation_year')->nullable();
            $table->string('program')->nullable();
            $table->string('department')->nullable();
        
            $table->string('current_company')->nullable();
            $table->string('current_role')->nullable();
        
            $table->json('skills')->nullable();
        
            $table->string('visibility')->default('public'); // public | institution_only
            $table->string('verification_status')->default('unverified'); // unverified|pending|verified|rejected
            $table->foreignId('verified_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('verified_at')->nullable();
        
            $table->timestamps();
        });
        
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('profiles');
    }
};
