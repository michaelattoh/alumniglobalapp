<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\StoryStoreRequest;
use App\Http\Resources\Api\StoryResource;
use App\Http\Resources\Api\StoryViewResource;
use App\Models\Story;
use App\Models\StoryRepost;
use App\Models\StoryShare;
use App\Models\StoryView;
use App\Models\DirectMessage;
use App\Models\UserBlock;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class StoryController extends Controller
{
    public function index(Request $request)
    {
        $viewer = $request->user();

        $query = Story::query()
            ->where('expires_at', '>', now())
            ->with([
                'user:id,name,institution_id',
                'user.profile:id,user_id,avatar_url',
                'media:id,story_id,type,url,thumbnail_url,position',
            ])
            ->withCount(['views', 'reactions'])
            ->latest();

        if (!$viewer) {
            $query->where('visibility', 'public');
        } elseif ($viewer->role !== 'super_admin') {
            $query->where(function ($q) use ($viewer) {
                $q->where('visibility', 'public');
                if ($viewer->institution_id) {
                    $q->orWhere(function ($sub) use ($viewer) {
                        $sub->where('visibility', 'institution_only')
                            ->where('institution_id', $viewer->institution_id);
                    });
                }
                $q->orWhere('user_id', $viewer->id);
            });
        }

        return $this->paginatedResponse($query->paginate((int) $request->query('per_page', 20)), StoryResource::class);
    }

    public function store(StoryStoreRequest $request)
    {
        $user = $request->user();
        $data = $request->validated();

        if ($data['visibility'] === 'institution_only' && !$user->institution_id && empty($data['institution_id'])) {
            return response()->json(['message' => 'Institution-only stories require an institution'], 422);
        }

        $story = Story::create([
            'user_id' => $user->id,
            'institution_id' => $data['institution_id'] ?? $user->institution_id,
            'visibility' => $data['visibility'],
            'caption' => $data['caption'] ?? null,
            'expires_at' => now()->addHours(24),
        ]);

        foreach ($data['media'] as $i => $item) {
            $story->media()->create([
                'type' => $item['type'],
                'url' => $item['url'],
                'thumbnail_url' => $item['thumbnail_url'] ?? null,
                'position' => $i,
            ]);
        }

        return response()->json([
            'message' => 'Story created',
            'story' => new StoryResource($story->load([
                'user:id,name,institution_id',
                'user.profile:id,user_id,avatar_url',
                'media',
            ])->loadCount('views')),
        ], 201);
    }

    public function view(Request $request, Story $story)
    {
        if (!$this->canViewStory($request->user(), $story)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($story->expires_at->isPast()) {
            return response()->json(['message' => 'Story expired'], 410);
        }

        StoryView::updateOrCreate(
            ['story_id' => $story->id, 'user_id' => $request->user()->id],
            ['viewed_at' => now()]
        );

        return response()->json(['message' => 'Story viewed']);
    }

    public function react(Request $request, Story $story, NotificationService $notificationService)
    {
        $actor = $request->user();

        if (!$this->canViewStory($actor, $story)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'emoji' => ['required', 'string', 'max:12'],
        ]);

        $reaction = $story->reactions()->updateOrCreate(
            ['user_id' => $actor->id],
            ['emoji' => $data['emoji']]
        );

        $this->notifyStoryOwner(
            actorId: (int) $actor->id,
            actorName: (string) $actor->name,
            story: $story,
            notificationService: $notificationService,
            type: 'story_reaction',
            title: 'New reaction on your story',
            body: $actor->name . ' reacted to your story.',
            data: [
                'reaction_id' => $reaction->id,
                'emoji' => $data['emoji'],
            ],
        );

        return response()->json(['message' => 'Reaction saved']);
    }

    public function repost(Request $request, Story $story, NotificationService $notificationService)
    {
        $actor = $request->user();

        if (!$this->canViewStory($actor, $story)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $repost = StoryRepost::firstOrCreate([
            'story_id' => $story->id,
            'user_id' => $actor->id,
        ]);

        if ($repost->wasRecentlyCreated) {
            $this->notifyStoryOwner(
                actorId: (int) $actor->id,
                actorName: (string) $actor->name,
                story: $story,
                notificationService: $notificationService,
                type: 'story_repost',
                title: 'Your story was reposted',
                body: $actor->name . ' reposted your story.',
                data: [
                    'repost_id' => $repost->id,
                ],
            );
        }

        return response()->json(['message' => 'Story reposted']);
    }

    public function unrepost(Request $request, Story $story)
    {
        StoryRepost::query()
            ->where('story_id', $story->id)
            ->where('user_id', $request->user()->id)
            ->delete();

        return response()->json(['message' => 'Story repost removed']);
    }

    public function share(Request $request, Story $story, NotificationService $notificationService)
    {
        $actor = $request->user();

        if (!$this->canViewStory($actor, $story)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'channel' => ['nullable', 'string', 'max:40'],
        ]);

        $share = StoryShare::firstOrCreate(
            [
                'story_id' => $story->id,
                'user_id' => $actor->id,
            ],
            [
                'channel' => $data['channel'] ?? null,
            ]
        );

        if ($share->wasRecentlyCreated) {
            $this->notifyStoryOwner(
                actorId: (int) $actor->id,
                actorName: (string) $actor->name,
                story: $story,
                notificationService: $notificationService,
                type: 'story_share',
                title: 'Your story was shared',
                body: $actor->name . ' shared your story.',
                data: [
                    'share_id' => $share->id,
                    'channel' => $share->channel,
                ],
            );
        }

        return response()->json(['message' => 'Story shared']);
    }

    public function reply(Request $request, Story $story, NotificationService $notificationService)
    {
        if (!$this->canViewStory($request->user(), $story)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'message' => ['nullable', 'string', 'max:500'],
            'emoji' => ['nullable', 'string', 'max:12'],
        ]);

        $messageText = trim(($data['message'] ?? ''));
        $emoji = trim(($data['emoji'] ?? ''));

        if ($messageText === '' && $emoji === '') {
            return response()->json(['message' => 'Message is required'], 422);
        }

        $actor = $request->user();
        $recipientId = $story->user_id;

        if ((int) $actor->id === (int) $recipientId) {
            return response()->json(['message' => 'Cannot reply to yourself'], 422);
        }

        if ($this->isBlockedEitherWay($actor->id, $recipientId)) {
            return response()->json(['message' => 'Messaging not allowed'], 403);
        }

        $body = $emoji !== '' ? $emoji : $messageText;
        $message = DirectMessage::create([
            'sender_id' => $actor->id,
            'recipient_id' => $recipientId,
            'body' => $body,
        ]);

        $notificationService->notify(
            $recipientId,
            'story_reply',
            'New reply to your story',
            $actor->name . ': ' . mb_substr($body, 0, 80),
            [
                'sender_id' => $actor->id,
                'sender_name' => $actor->name,
                'message_id' => $message->id,
                'story_id' => $story->id,
            ]
        );

        return response()->json(['message' => 'Reply sent']);
    }

    public function reactions(Request $request, Story $story)
    {
        if (!$this->canViewStory($request->user(), $story)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $counts = $story->reactions()
            ->selectRaw('emoji, COUNT(*) as total')
            ->groupBy('emoji')
            ->orderByDesc('total')
            ->get();

        return response()->json(['data' => $counts]);
    }

    public function views(Request $request, Story $story)
    {
        $actor = $request->user();

        $canSeeViews = $actor->id === $story->user_id || $actor->role === 'super_admin';
        if (!$canSeeViews && ($actor->role === 'institution_admin' || $actor->role === 'admin')) {
            $canSeeViews = $actor->institution_id && (int) $actor->institution_id === (int) $story->institution_id;
        }

        if (!$canSeeViews) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $views = $story->views()->with('user:id,name')->latest('viewed_at')->paginate((int) $request->query('per_page', 30));

        return response()->json([
            'count' => $story->views()->count(),
            ...$this->collectionResponse(collect($views->items()), StoryViewResource::class),
            'meta' => $this->paginationMeta($views),
        ]);
    }

    public function destroy(Request $request, Story $story)
    {
        $actor = $request->user();
        $canDelete = $actor->id === $story->user_id || $actor->role === 'super_admin';

        if (!$canDelete && ($actor->role === 'institution_admin' || $actor->role === 'admin')) {
            $canDelete = $actor->institution_id && (int) $actor->institution_id === (int) $story->institution_id;
        }

        if (!$canDelete) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        DB::transaction(function () use ($story) {
            if (Schema::hasTable('story_media')) {
                $story->media()->delete();
            }
            if (Schema::hasTable('story_views')) {
                $story->views()->delete();
            }
            if (Schema::hasTable('story_reactions')) {
                $story->reactions()->delete();
            }
            if (Schema::hasTable('story_reposts')) {
                $story->reposts()->delete();
            }
            if (Schema::hasTable('story_shares')) {
                $story->shares()->delete();
            }
            $story->delete();
        });

        return response()->json(['message' => 'Story deleted']);
    }

    private function canViewStory($viewer, Story $story): bool
    {
        if (!$viewer) {
            return $story->visibility === 'public';
        }

        if ((int) $story->user_id === (int) $viewer->id) {
            return true;
        }

        if ($viewer->role === 'super_admin') {
            return true;
        }

        if ($story->visibility === 'public') {
            return true;
        }

        return $viewer->institution_id && (int) $viewer->institution_id === (int) $story->institution_id;
    }

    private function isBlockedEitherWay(int $a, int $b): bool
    {
        return UserBlock::where('blocker_id', $a)->where('blocked_id', $b)->exists()
            || UserBlock::where('blocker_id', $b)->where('blocked_id', $a)->exists();
    }

    private function notifyStoryOwner(
        int $actorId,
        string $actorName,
        Story $story,
        NotificationService $notificationService,
        string $type,
        string $title,
        ?string $body,
        array $data = []
    ): void {
        if ((int) $story->user_id === $actorId) {
            return;
        }

        $notificationService->notify(
            (int) $story->user_id,
            $type,
            $title,
            $body,
            array_merge($data, [
                'story_id' => $story->id,
                'from_user_id' => $actorId,
                'from_user_name' => $actorName,
            ])
        );
    }
}
