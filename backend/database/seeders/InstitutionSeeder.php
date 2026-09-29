<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;
use App\Models\Institution;
use App\Models\InvitationCode;


class InstitutionSeeder extends Seeder
{
    public function run(): void
    {
        $inst = Institution::firstOrCreate(
            ['slug' => 'sample-university'],
            ['name' => 'Sample University', 'status' => 'active']
        );

        InvitationCode::firstOrCreate(
            ['code' => 'ALUMNI-2026'],
            [
                'institution_id' => $inst->id,
                'role' => 'alumni',
                'max_uses' => 500,
                'used_count' => 0,
                'is_active' => true,
                'expires_at' => now()->addMonths(6),
            ]
        );

        InvitationCode::firstOrCreate(
            ['code' => 'ADMIN-2026'],
            [
                'institution_id' => $inst->id,
                'role' => 'institution_admin',
                'max_uses' => 10,
                'used_count' => 0,
                'is_active' => true,
                'expires_at' => now()->addMonths(6),
            ]
        );
    }
}
