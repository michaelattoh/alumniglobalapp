<?php

use App\Models\Institution;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('institutions', function (Blueprint $table) {
            $table->string('school_id', 20)->nullable()->unique()->after('name');
        });

        Institution::query()
            ->whereNull('school_id')
            ->orderBy('id')
            ->chunkById(100, function ($institutions) {
                foreach ($institutions as $institution) {
                    do {
                        $code = 'SCH-' . Str::upper(Str::random(6));
                    } while (Institution::where('school_id', $code)->exists());

                    $institution->school_id = $code;
                    $institution->save();
                }
            });
    }

    public function down(): void
    {
        Schema::table('institutions', function (Blueprint $table) {
            $table->dropUnique(['school_id']);
            $table->dropColumn('school_id');
        });
    }
};
