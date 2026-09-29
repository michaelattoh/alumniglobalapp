<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->index('institution_id');
            $table->index('name');
        });

        Schema::table('profiles', function (Blueprint $table) {
            $table->index('visibility');
            $table->index('verification_status');
            $table->index('graduation_year');
            $table->index(['program']);
            $table->index(['department']);
            $table->index(['user_id']);
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['institution_id']);
            $table->dropIndex(['name']);
        });

        Schema::table('profiles', function (Blueprint $table) {
            $table->dropIndex(['visibility']);
            $table->dropIndex(['verification_status']);
            $table->dropIndex(['graduation_year']);
            $table->dropIndex(['program']);
            $table->dropIndex(['department']);
            $table->dropIndex(['user_id']);
        });
    }
};

