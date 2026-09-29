<?php

use App\Models\Post;
use App\Models\Profile;
use App\Models\User;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        $user = User::firstOrCreate(
            ['email' => 'welcome@alumniglobalnetwork.com'],
            [
                'name' => 'Alumni Global Network',
                'password' => Hash::make(Str::random(24)),
                'role' => 'alumni',
                'status' => 'active',
                'email_verified_at' => now(),
            ]
        );

        if (!$user->profile) {
            $user->profile()->create([
                'verification_status' => 'verified',
                'verified_at' => now(),
                'visibility' => 'public',
            ]);
        }

        Post::firstOrCreate(
            [
                'user_id' => $user->id,
                'content' => "Welcome to Alumni Global Network!\n\nWe are proud to bring together graduates from across the world into one powerful, connected community. This is your space to reconnect with classmates, expand your professional network, share opportunities, and celebrate achievements.\n\nTogether, we grow. Together, we lead. Together, we build a global legacy.",
            ],
            [
                'visibility' => 'public',
                'is_pinned' => true,
            ]
        );
    }

    public function down(): void
    {
        // Leave the welcome post and user in place.
    }
};
