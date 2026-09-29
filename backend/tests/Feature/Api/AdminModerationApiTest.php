<?php

namespace Tests\Feature\Api;

use App\Models\Institution;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminModerationApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_institution_admin_can_suspend_and_reactivate_user_in_same_institution(): void
    {
        $institution = Institution::create(['name' => 'Admin Uni', 'slug' => 'admin-uni', 'status' => 'active']);

        $admin = User::factory()->create([
            'role' => 'institution_admin',
            'institution_id' => $institution->id,
        ]);

        $target = User::factory()->create([
            'role' => 'alumni',
            'institution_id' => $institution->id,
            'status' => 'active',
        ]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/users/' . $target->id . '/suspend')
            ->assertOk()
            ->assertJsonPath('message', 'User suspended');

        $this->assertDatabaseHas('users', [
            'id' => $target->id,
            'status' => 'suspended',
        ]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/users/' . $target->id . '/reactivate')
            ->assertOk()
            ->assertJsonPath('message', 'User reactivated');

        $this->assertDatabaseHas('users', [
            'id' => $target->id,
            'status' => 'active',
        ]);
    }

    public function test_institution_admin_cannot_suspend_user_from_another_institution(): void
    {
        $institutionA = Institution::create(['name' => 'Admin A', 'slug' => 'admin-a', 'status' => 'active']);
        $institutionB = Institution::create(['name' => 'Admin B', 'slug' => 'admin-b', 'status' => 'active']);

        $admin = User::factory()->create([
            'role' => 'institution_admin',
            'institution_id' => $institutionA->id,
        ]);

        $target = User::factory()->create([
            'role' => 'alumni',
            'institution_id' => $institutionB->id,
            'status' => 'active',
        ]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/users/' . $target->id . '/suspend')
            ->assertForbidden();

        $this->assertDatabaseHas('users', [
            'id' => $target->id,
            'status' => 'active',
        ]);
    }

    public function test_profile_verification_and_rejection_follow_role_and_institution_rules(): void
    {
        $institution = Institution::create(['name' => 'Verify Uni', 'slug' => 'verify-uni', 'status' => 'active']);

        $admin = User::factory()->create([
            'role' => 'institution_admin',
            'institution_id' => $institution->id,
        ]);

        $member = User::factory()->create([
            'role' => 'alumni',
            'institution_id' => $institution->id,
        ]);
        $member->profile()->create([
            'visibility' => 'public',
            'verification_status' => 'pending',
        ]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/profiles/' . $member->id . '/verify')
            ->assertOk()
            ->assertJsonPath('message', 'Profile verified');

        $this->assertDatabaseHas('profiles', [
            'user_id' => $member->id,
            'verification_status' => 'verified',
            'verified_by' => $admin->id,
        ]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/profiles/' . $member->id . '/reject', ['reason' => 'mismatch'])
            ->assertOk()
            ->assertJsonPath('message', 'Profile rejected');

        $this->assertDatabaseHas('profiles', [
            'user_id' => $member->id,
            'verification_status' => 'rejected',
            'verified_by' => $admin->id,
        ]);
    }

    public function test_institution_admin_can_pin_and_unpin_post_in_same_institution_only(): void
    {
        $institutionA = Institution::create(['name' => 'Pin A', 'slug' => 'pin-a', 'status' => 'active']);
        $institutionB = Institution::create(['name' => 'Pin B', 'slug' => 'pin-b', 'status' => 'active']);

        $admin = User::factory()->create([
            'role' => 'institution_admin',
            'institution_id' => $institutionA->id,
        ]);

        $authorA = User::factory()->create(['role' => 'alumni', 'institution_id' => $institutionA->id]);
        $postA = Post::create([
            'user_id' => $authorA->id,
            'institution_id' => $institutionA->id,
            'content' => 'Pin this',
            'visibility' => 'institution_only',
        ]);

        $authorB = User::factory()->create(['role' => 'alumni', 'institution_id' => $institutionB->id]);
        $postB = Post::create([
            'user_id' => $authorB->id,
            'institution_id' => $institutionB->id,
            'content' => 'Do not pin',
            'visibility' => 'institution_only',
        ]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/posts/' . $postA->id . '/pin')
            ->assertOk();

        $this->assertDatabaseHas('posts', [
            'id' => $postA->id,
            'is_pinned' => 1,
            'pinned_by' => $admin->id,
        ]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/posts/' . $postA->id . '/unpin')
            ->assertOk();

        $this->assertDatabaseHas('posts', [
            'id' => $postA->id,
            'is_pinned' => 0,
        ]);

        $this->actingAs($admin, 'sanctum')
            ->postJson('/api/posts/' . $postB->id . '/pin')
            ->assertForbidden();
    }

    public function test_super_admin_can_moderate_across_institutions(): void
    {
        $institution = Institution::create(['name' => 'Global', 'slug' => 'global', 'status' => 'active']);

        $superAdmin = User::factory()->create([
            'role' => 'super_admin',
            'institution_id' => null,
        ]);

        $target = User::factory()->create([
            'role' => 'alumni',
            'institution_id' => $institution->id,
            'status' => 'active',
        ]);

        $this->actingAs($superAdmin, 'sanctum')
            ->postJson('/api/users/' . $target->id . '/suspend')
            ->assertOk();

        $this->assertDatabaseHas('users', [
            'id' => $target->id,
            'status' => 'suspended',
        ]);
    }
}
