<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('profiles', function (Blueprint $table) {
            $table->string('industry')->nullable()->after('current_role');
            $table->string('career_focus')->nullable()->after('industry');
            $table->json('interests')->nullable()->after('skills');
        });
    }

    public function down(): void
    {
        Schema::table('profiles', function (Blueprint $table) {
            $table->dropColumn(['industry', 'career_focus', 'interests']);
        });
    }
};
