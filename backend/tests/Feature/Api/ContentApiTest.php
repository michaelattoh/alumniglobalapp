<?php

namespace Tests\Feature\Api;

use App\Models\Institution;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\Story;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ContentApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_create_and_list_posts(): void
    {
        $institution = Institution::create(['name' => 'Uni Feed', 'slug' => 'uni-feed', 'status' => 'active']);
        $user = User::factory()->create(['role' => 'alumni', 'institution_id' => $institution->id]);
        $user->profile()->create(['visibility' => 'public', 'verification_status' => 'verified']);

        $create = $this->actingAs($user, 'sanctum')->postJson('/api/posts', [
            'content' => 'Hello alumni world',
            'visibility' => 'public',
            'media' => [
                ['type' => 'image', 'url' => 'https://cdn.test/image.jpg'],
            ],
        ]);

        $create->assertCreated()
            ->assertJsonPath('post.content', 'Hello alumni world');

        $list = $this->actingAs($user, 'sanctum')->getJson('/api/posts');
        $list->assertOk()
            ->assertJsonPath('data.0.content', 'Hello alumni world');
    }

    public function test_comment_parent_must_belong_to_same_post(): void
    {
        $user = User::factory()->create(['role' => 'alumni']);
        $user->profile()->create(['visibility' => 'public', 'verification_status' => 'verified']);

        $postA = Post::create(['user_id' => $user->id, 'content' => 'Post A', 'visibility' => 'public']);
        $postB = Post::create(['user_id' => $user->id, 'content' => 'Post B', 'visibility' => 'public']);

        $foreignComment = PostComment::create([
            'post_id' => $postB->id,
            'user_id' => $user->id,
            'content' => 'Parent for B',
        ]);

        $response = $this->actingAs($user, 'sanctum')->postJson('/api/posts/' . $postA->id . '/comments', [
            'content' => 'Reply on wrong post',
            'parent_id' => $foreignComment->id,
        ]);

        $response->assertUnprocessable()
            ->assertJsonPath('message', 'Invalid parent comment for this post');
    }

    public function test_like_and_unlike_post(): void
    {
        $author = User::factory()->create(['role' => 'alumni']);
        $author->profile()->create(['visibility' => 'public', 'verification_status' => 'verified']);
        $post = Post::create(['user_id' => $author->id, 'content' => 'Like me', 'visibility' => 'public']);

        $viewer = User::factory()->create(['role' => 'alumni']);
        $viewer->profile()->create(['visibility' => 'public', 'verification_status' => 'verified']);

        $this->actingAs($viewer, 'sanctum')->postJson('/api/posts/' . $post->id . '/like')->assertOk();
        $this->assertDatabaseHas('post_reactions', [
            'post_id' => $post->id,
            'user_id' => $viewer->id,
            'type' => 'like',
        ]);

        $this->actingAs($viewer, 'sanctum')->deleteJson('/api/posts/' . $post->id . '/like')->assertOk();
        $this->assertDatabaseMissing('post_reactions', [
            'post_id' => $post->id,
            'user_id' => $viewer->id,
            'type' => 'like',
        ]);
    }

    public function test_story_lifecycle_create_view_and_visibility_filtering(): void
    {
        $institutionA = Institution::create(['name' => 'Uni Story A', 'slug' => 'uni-story-a', 'status' => 'active']);
        $institutionB = Institution::create(['name' => 'Uni Story B', 'slug' => 'uni-story-b', 'status' => 'active']);

        $author = User::factory()->create(['role' => 'alumni', 'institution_id' => $institutionA->id]);
        $author->profile()->create(['visibility' => 'public', 'verification_status' => 'verified']);

        $create = $this->actingAs($author, 'sanctum')->postJson('/api/stories', [
            'caption' => 'Institution-only story',
            'visibility' => 'institution_only',
            'media' => [
                ['type' => 'image', 'url' => 'https://cdn.test/story.jpg'],
            ],
        ]);

        $create->assertCreated();
        $storyId = $create->json('story.id');

        $sameInstitutionViewer = User::factory()->create(['role' => 'alumni', 'institution_id' => $institutionA->id]);
        $sameInstitutionViewer->profile()->create(['visibility' => 'public', 'verification_status' => 'verified']);

        $this->actingAs($sameInstitutionViewer, 'sanctum')
            ->postJson('/api/stories/' . $storyId . '/view')
            ->assertOk();

        $this->assertDatabaseHas('story_views', [
            'story_id' => $storyId,
            'user_id' => $sameInstitutionViewer->id,
        ]);

        $differentInstitutionViewer = User::factory()->create(['role' => 'alumni', 'institution_id' => $institutionB->id]);
        $differentInstitutionViewer->profile()->create(['visibility' => 'public', 'verification_status' => 'verified']);

        $differentList = $this->actingAs($differentInstitutionViewer, 'sanctum')->getJson('/api/stories');
        $differentList->assertOk();
        $this->assertEmpty($differentList->json('data'));

        $sameList = $this->actingAs($sameInstitutionViewer, 'sanctum')->getJson('/api/stories');
        $sameList->assertOk();
        $this->assertSame($storyId, $sameList->json('data.0.id'));

        $story = Story::findOrFail($storyId);
        $this->assertTrue($story->expires_at->greaterThan(now()->addHours(23)));
    }
}
