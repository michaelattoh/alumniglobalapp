<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Auth\Notifications\VerifyEmail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class AuthApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register_and_get_token(): void
    {
        Notification::fake();

        $response = $this->postJson('/api/auth/register', [
            'name' => 'Jane Alumni',
            'email' => 'jane@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'user_type' => 'alumni',
        ]);

        $response->assertCreated()
            ->assertJsonPath('user.email', 'jane@example.com')
            ->assertJsonPath('user.role', 'alumni')
            ->assertJsonStructure([
                'token',
                'user' => ['id', 'name', 'email', 'role'],
            ]);

        $user = User::where('email', 'jane@example.com')->first();
        $this->assertNotNull($user);
        Notification::assertSentTo($user, VerifyEmail::class);
        $this->assertDatabaseHas('profiles', [
            'user_id' => $user->id,
            'verification_status' => 'unverified',
        ]);
    }

    public function test_register_requires_school_name_for_school_user_type_without_code(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'School Admin',
            'email' => 'admin@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
            'user_type' => 'school',
        ]);

        $response->assertUnprocessable()
            ->assertJsonPath('errors.school_name.0', 'The school_name field is required when user_type is school.');
    }

    public function test_user_can_login_and_receive_token(): void
    {
        $user = User::factory()->create([
            'email' => 'login@example.com',
            'password' => bcrypt('Password123!'),
            'role' => 'alumni',
        ]);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'login@example.com',
            'password' => 'Password123!',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonStructure(['token', 'user' => ['id', 'name', 'email', 'role']]);
    }

    public function test_login_fails_with_invalid_credentials(): void
    {
        User::factory()->create([
            'email' => 'wrong@example.com',
            'password' => bcrypt('Password123!'),
            'role' => 'alumni',
        ]);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'wrong@example.com',
            'password' => 'invalid',
        ]);

        $response->assertUnprocessable()
            ->assertJsonPath('message', 'Invalid credentials');
    }
}
