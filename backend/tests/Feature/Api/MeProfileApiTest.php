<?php

namespace Tests\Feature\Api;

use App\Models\Institution;
use App\Models\InvitationCode;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MeProfileApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_me_endpoint_returns_user_and_profile(): void
    {
        $institution = Institution::create(['name' => 'Uni One', 'slug' => 'uni-one', 'status' => 'active']);
        $user = User::factory()->create(['role' => 'alumni', 'institution_id' => $institution->id]);

        $user->profile()->create([
            'headline' => 'Mobile Engineer',
            'visibility' => 'public',
            'verification_status' => 'unverified',
        ]);

        $response = $this->actingAs($user, 'sanctum')->getJson('/api/me');

        $response->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('profile.headline', 'Mobile Engineer');
    }

    public function test_user_can_update_me_profile_data(): void
    {
        $user = User::factory()->create(['role' => 'alumni']);
        $user->profile()->create([
            'visibility' => 'public',
            'verification_status' => 'unverified',
        ]);

        $response = $this->actingAs($user, 'sanctum')->patchJson('/api/me', [
            'name' => 'Updated Name',
            'headline' => 'Product Designer',
            'skills' => ['Flutter', 'Laravel'],
            'visibility' => 'institution_only',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.name', 'Updated Name')
            ->assertJsonPath('profile.visibility', 'institution_only');

        $this->assertDatabaseHas('profiles', [
            'user_id' => $user->id,
            'headline' => 'Product Designer',
            'visibility' => 'institution_only',
        ]);
    }

    public function test_alumni_can_attach_institution_with_valid_invitation_code(): void
    {
        $institution = Institution::create(['name' => 'Uni Two', 'slug' => 'uni-two', 'status' => 'active']);
        $user = User::factory()->create(['role' => 'alumni']);
        $user->profile()->create([
            'visibility' => 'public',
            'verification_status' => 'unverified',
        ]);

        $invite = InvitationCode::create([
            'code' => 'ALUM-2026',
            'institution_id' => $institution->id,
            'role' => 'alumni',
            'max_uses' => 2,
            'used_count' => 0,
            'is_active' => true,
        ]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/me/attach-institution', [
            'code' => 'ALUM-2026',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.institution.id', $institution->id)
            ->assertJsonPath('profile.verification_status', 'pending');

        $this->assertDatabaseHas('invitation_codes', [
            'id' => $invite->id,
            'used_count' => 1,
        ]);
    }

    public function test_profile_visibility_blocks_different_institution_user(): void
    {
        $institutionA = Institution::create(['name' => 'Uni A', 'slug' => 'uni-a', 'status' => 'active']);
        $institutionB = Institution::create(['name' => 'Uni B', 'slug' => 'uni-b', 'status' => 'active']);

        $owner = User::factory()->create(['role' => 'alumni', 'institution_id' => $institutionA->id]);
        $owner->profile()->create([
            'visibility' => 'institution_only',
            'verification_status' => 'verified',
        ]);

        $viewer = User::factory()->create(['role' => 'alumni', 'institution_id' => $institutionB->id]);

        $response = $this->actingAs($viewer, 'sanctum')->getJson('/api/profiles/' . $owner->id);

        $response->assertForbidden();
    }
}
