<?php

namespace Tests\Feature\Api;

use App\Models\ConnectionRequest;
use App\Models\Event;
use App\Models\Institution;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DiscoveryEventsMessagingApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_global_feed_supports_sorting_and_announcements(): void
    {
        $superAdmin = User::factory()->create(['role' => 'super_admin']);
        $institution = Institution::create(['name' => 'Feed U', 'slug' => 'feed-u', 'status' => 'active']);

        $author = User::factory()->create(['role' => 'alumni', 'institution_id' => $institution->id]);
        $post = Post::create([
            'user_id' => $author->id,
            'institution_id' => $institution->id,
            'content' => 'Rank me',
            'visibility' => 'public',
            'engagement_score' => 12,
            'ai_rank_score' => 42,
        ]);

        $this->actingAs($superAdmin, 'sanctum')->postJson('/api/announcements', [
            'title' => 'Global update',
            'body' => 'System maintenance',
            'audience' => 'global',
        ])->assertCreated();

        $feed = $this->actingAs($author, 'sanctum')->getJson('/api/feed/global?sort=ai');
        $feed->assertOk()
            ->assertJsonPath('sort', 'ai')
            ->assertJsonPath('announcements.data.0.title', 'Global update');

        $feed->assertJsonFragment(['id' => $post->id, 'content' => 'Rank me']);
    }

    public function test_event_capacity_blocks_extra_going_rsvp(): void
    {
        $institution = Institution::create(['name' => 'Event U', 'slug' => 'event-u', 'status' => 'active']);
        $admin = User::factory()->create(['role' => 'institution_admin', 'institution_id' => $institution->id]);

        $create = $this->actingAs($admin, 'sanctum')->postJson('/api/events', [
            'title' => 'Small dinner',
            'event_type' => 'physical',
            'starts_at' => now()->addDay()->toISOString(),
            'capacity' => 1,
            'institution_id' => $institution->id,
        ]);

        $create->assertCreated();
        $eventId = $create->json('event.id');

        $a = User::factory()->create(['role' => 'alumni', 'institution_id' => $institution->id]);
        $b = User::factory()->create(['role' => 'alumni', 'institution_id' => $institution->id]);

        $this->actingAs($a, 'sanctum')->postJson('/api/events/' . $eventId . '/rsvp', [
            'status' => 'going',
        ])->assertOk();

        $this->actingAs($b, 'sanctum')->postJson('/api/events/' . $eventId . '/rsvp', [
            'status' => 'going',
        ])->assertUnprocessable()
            ->assertJsonPath('message', 'Event capacity reached');
    }

    public function test_connection_acceptance_enables_messaging(): void
    {
        $a = User::factory()->create(['role' => 'alumni']);
        $b = User::factory()->create(['role' => 'alumni']);

        $this->actingAs($a, 'sanctum')->postJson('/api/connections/' . $b->id, [
            'message' => 'Let us connect',
        ])->assertCreated();

        $connection = ConnectionRequest::where('from_user_id', $a->id)
            ->where('to_user_id', $b->id)
            ->firstOrFail();

        $this->actingAs($b, 'sanctum')->postJson('/api/connections/' . $connection->id . '/respond', [
            'status' => 'accepted',
        ])->assertOk();

        $this->actingAs($a, 'sanctum')->postJson('/api/messages/' . $b->id, [
            'body' => 'Hi from A',
        ])->assertCreated();

        $thread = $this->actingAs($b, 'sanctum')->getJson('/api/messages/' . $a->id);
        $thread->assertOk()
            ->assertJsonPath('data.0.body', 'Hi from A');
    }

    public function test_blocking_prevents_connection_and_messages(): void
    {
        $a = User::factory()->create(['role' => 'alumni']);
        $b = User::factory()->create(['role' => 'alumni']);

        $this->actingAs($b, 'sanctum')->postJson('/api/users/' . $a->id . '/block', [
            'reason' => 'spam',
        ])->assertOk();

        $this->actingAs($a, 'sanctum')->postJson('/api/connections/' . $b->id)
            ->assertForbidden();

        $this->actingAs($a, 'sanctum')->postJson('/api/messages/' . $b->id, [
            'body' => 'Hello',
        ])->assertForbidden();
    }

    public function test_notification_preferences_and_mark_read_flow(): void
    {
        $user = User::factory()->create(['role' => 'alumni']);

        $prefs = $this->actingAs($user, 'sanctum')->patchJson('/api/notification-preferences', [
            'push_enabled' => false,
            'email_enabled' => true,
            'events_enabled' => false,
        ]);
        $prefs->assertOk()
            ->assertJsonPath('data.push_enabled', false)
            ->assertJsonPath('data.email_enabled', true)
            ->assertJsonPath('data.events_enabled', false);

        $other = User::factory()->create(['role' => 'alumni']);
        $this->actingAs($other, 'sanctum')->postJson('/api/connections/' . $user->id)
            ->assertCreated();

        $notifications = $this->actingAs($user, 'sanctum')->getJson('/api/notifications');
        $notifications->assertOk();
        $id = $notifications->json('data.0.id');

        $this->actingAs($user, 'sanctum')->postJson('/api/notifications/' . $id . '/read')
            ->assertOk();

        $this->actingAs($user, 'sanctum')->postJson('/api/notifications/read-all')
            ->assertOk();
    }
}
