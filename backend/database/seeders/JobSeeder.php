<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Job;
use App\Models\Institution;

class JobSeeder extends Seeder
{
    public function run(): void
    {
        $institution = Institution::first();

        Job::firstOrCreate(
            ['title' => 'Flutter Developer', 'company_name' => 'Verix Teams'],
            [
                'institution_id' => $institution?->id,
                'category' => 'Tech',
                'location' => 'Remote',
                'salary' => '₵8,000 – ₵12,000',
                'overview' => 'Join a fast-growing product team building scalable platforms.',
                'description' => 'You will work closely with designers and backend engineers.',
                'expectations' => ['Build Flutter apps', 'Integrate APIs', 'Write clean code'],
                'requirements' => ['Flutter & Dart', 'REST APIs', 'Git'],
                'company_overview' => 'Verix Teams builds modern digital solutions across Africa.',
                'is_active' => true,
                'published_at' => now()->subDays(2),
            ]
        );

        Job::firstOrCreate(
            ['title' => 'UI/UX Designer', 'company_name' => 'Alpha Beta College'],
            [
                'institution_id' => $institution?->id,
                'category' => 'Design',
                'location' => 'Accra',
                'salary' => '₵5,000 – ₵7,000',
                'overview' => 'Design intuitive user experiences for education platforms.',
                'description' => 'You will lead UI design across web and mobile products.',
                'expectations' => ['Create wireframes', 'User research', 'Collaborate with devs'],
                'requirements' => ['Figma', 'UX research', 'Design systems'],
                'company_overview' => 'Alpha Beta College is a leading private institution.',
                'is_active' => true,
                'published_at' => now()->subDays(5),
            ]
        );
    }
}
