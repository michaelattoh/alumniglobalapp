<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('institutions', function (Blueprint $table) {
            $table->string('logo_url')->nullable()->after('status');
            $table->string('banner_url')->nullable()->after('logo_url');
            $table->string('website')->nullable()->after('banner_url');
            $table->string('email')->nullable()->after('website');
            $table->string('phone')->nullable()->after('email');
            $table->string('location')->nullable()->after('phone');
            $table->string('address')->nullable()->after('location');
            $table->text('description')->nullable()->after('address');
        });
    }

    public function down(): void
    {
        Schema::table('institutions', function (Blueprint $table) {
            $table->dropColumn([
                'logo_url',
                'banner_url',
                'website',
                'email',
                'phone',
                'location',
                'address',
                'description',
            ]);
        });
    }
};
