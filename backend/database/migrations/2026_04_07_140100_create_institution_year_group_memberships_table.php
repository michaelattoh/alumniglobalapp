<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('institution_year_group_memberships', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('institution_year_group_id');
            $table->unsignedBigInteger('user_id');
            $table->string('status', 20)->default('pending');
            $table->text('intro')->nullable();
            $table->unsignedBigInteger('approved_by')->nullable();
            $table->timestamp('approved_at')->nullable();
            $table->timestamps();

            $table->unique(['institution_year_group_id', 'user_id'], 'institution_year_group_user_unique');
            $table->index(['status', 'created_at']);
            $table->foreign('institution_year_group_id', 'iygm_group_fk')
                ->references('id')
                ->on('institution_year_groups')
                ->cascadeOnDelete();
            $table->foreign('user_id', 'iygm_user_fk')
                ->references('id')
                ->on('users')
                ->cascadeOnDelete();
            $table->foreign('approved_by', 'iygm_approved_by_fk')
                ->references('id')
                ->on('users')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('institution_year_group_memberships');
    }
};
