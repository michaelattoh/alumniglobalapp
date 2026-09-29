<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\PostCommentStoreRequest;
use App\Http\Requests\Api\PostReportRequest;
use App\Http\Requests\Api\PostStoreRequest;
use App\Http\Resources\Api\PostCommentResource;
use App\Http\Resources\Api\PostResource;
use App\Models\ConnectionRequest;
use App\Models\InstitutionMembership;
use App\Models\Post;
use App\Models\PostComment;
use App\Models\PostCommentReaction;
use App\Models\PostHide;
use App\Models\PostReaction;
use App\Models\PostRepost;
use App\Models\PostReport;
use App\Models\PostSave;
use App\Models\PostShare;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Schema;

class PostController extends Controller
{
    private array $tableExistsCache = [];

    public function index(Request $request)
    {
        $viewer = $request->user();
        $viewerInstitutionIds = $viewer ? $this->accessibleInstitutionIdsForUser($viewer) : [];

        $query = Post::query()
            ->with([
                'user:id,name,institution_id',
                'user.profile:id,user_id,avatar_url',
                'media:id,post_id,type,url,thumbnail_url,position',
            ]);
        if ($counts = $this->availablePostCountRelations()) {
            $query->withCount($counts);
        }
        $query
            ->latest();
        $query->where(function ($q) {
            $q->whereNull('scheduled_at')
              ->orWhere('scheduled_at', '<=', now());
        });

        if ($viewer && Schema::hasTable('post_hides')) {
            $query->whereDoesntHave('hides', function ($q) use ($viewer) {
                $q->where('user_id', $viewer->id);
            });
        }

        if ($viewer && Schema::hasTable('user_mutes')) {
            $query->whereNotIn('user_id', function ($sub) use ($viewer) {
                $sub->select('muted_user_id')
                    ->from('user_mutes')
                    ->where('user_id', $viewer->id);
            });
        }

        if ($request->filled('institution_id')) {
            $query->where('institution_id', (int) $request->query('institution_id'));
        }

        if (!$viewer) {
            $query->where('visibility', 'public');
        } elseif ($viewer->role !== 'super_admin') {
            $query->where(function ($q) use ($viewer, $viewerInstitutionIds) {
                $q->where('visibility', 'public');
                if (!empty($viewerInstitutionIds)) {
                    $q->orWhere(function ($sub) use ($viewerInstitutionIds) {
                        $sub->where('visibility', 'institution_only')
                            ->whereIn('institution_id', $viewerInstitutionIds);
                    });
                }
                $q->orWhere('user_id', $viewer->id);
            });
        }

        $posts = $query->paginate((int) $request->query('per_page', 20));
        $posts->getCollection()->transform(
            fn (Post $post) => $this->applyViewerFlags($post, $viewer?->id)
        );

        return $this->paginatedResponse($posts, PostResource::class);
    }

    public function saved(Request $request)
    {
        $viewer = $request->user();
        if (!$viewer) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }
        $viewerInstitutionIds = $this->accessibleInstitutionIdsForUser($viewer);

        $query = Post::query()
            ->with([
                'user:id,name,institution_id',
                'user.profile:id,user_id,avatar_url',
                'media:id,post_id,type,url,thumbnail_url,position',
            ]);
        if ($counts = $this->availablePostCountRelations()) {
            $query->withCount($counts);
        }
        $query
            ->whereHas('saves', function ($q) use ($viewer) {
                $q->where('user_id', $viewer->id);
            })
            ->latest();
        $query->where(function ($q) {
            $q->whereNull('scheduled_at')
              ->orWhere('scheduled_at', '<=', now());
        });

        if ($viewer->role !== 'super_admin') {
            $query->where(function ($q) use ($viewerInstitutionIds) {
                $q->where('visibility', 'public');
                if (!empty($viewerInstitutionIds)) {
                    $q->orWhere(function ($sub) use ($viewerInstitutionIds) {
                        $sub->where('visibility', 'institution_only')
                            ->whereIn('institution_id', $viewerInstitutionIds);
                    });
                }
            });
        }

        $posts = $query->paginate((int) $request->query('per_page', 20));
        $posts->getCollection()->transform(fn (Post $post) => $this->applyViewerFlags($post, $viewer->id));

        return $this->paginatedResponse($posts, PostResource::class);
    }

    public function hidden(Request $request)
    {
        $viewer = $request->user();
        if (!$viewer) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }
        $viewerInstitutionIds = $this->accessibleInstitutionIdsForUser($viewer);

        $query = Post::query()
            ->with([
                'user:id,name,institution_id',
                'user.profile:id,user_id,avatar_url',
                'media:id,post_id,type,url,thumbnail_url,position',
            ]);
        if ($counts = $this->availablePostCountRelations()) {
            $query->withCount($counts);
        }
        $query
            ->when(
                Schema::hasTable('post_hides'),
                fn ($builder) => $builder->whereHas('hides', function ($q) use ($viewer) {
                    $q->where('user_id', $viewer->id);
                }),
                fn ($builder) => $builder->whereRaw('1 = 0')
            )
            ->latest();
        $query->where(function ($q) {
            $q->whereNull('scheduled_at')
              ->orWhere('scheduled_at', '<=', now());
        });

        if ($viewer->role !== 'super_admin') {
            $query->where(function ($q) use ($viewerInstitutionIds) {
                $q->where('visibility', 'public');
                if (!empty($viewerInstitutionIds)) {
                    $q->orWhere(function ($sub) use ($viewerInstitutionIds) {
                        $sub->where('visibility', 'institution_only')
                            ->whereIn('institution_id', $viewerInstitutionIds);
                    });
                }
            });
        }

        $posts = $query->paginate((int) $request->query('per_page', 20));
        $posts->getCollection()->transform(fn (Post $post) => $this->applyViewerFlags($post, $viewer->id));

        return $this->paginatedResponse($posts, PostResource::class);
    }

    public function store(PostStoreRequest $request, NotificationService $notificationService)
    {
        $user = $request->user();
        $data = $request->validated();
        $accessibleInstitutionIds = $this->accessibleInstitutionIdsForUser($user);

        if (empty($data['content']) && empty($data['media'])) {
            return response()->json(['message' => 'Post content or media is required'], 422);
        }

        if (($data['visibility'] ?? 'public') === 'institution_only' && empty($accessibleInstitutionIds) && empty($data['institution_id'])) {
            return response()->json(['message' => 'Institution-only posts require an institution'], 422);
        }

        $institutionId = $data['institution_id'] ?? ($accessibleInstitutionIds[0] ?? null);

        if (($data['visibility'] ?? 'public') === 'institution_only') {
            if ($institutionId === null || !in_array((int) $institutionId, $accessibleInstitutionIds, true)) {
                return response()->json(['message' => 'You can only post to a school you belong to'], 403);
            }
        }

        $post = Post::create([
            'user_id' => $user->id,
            'institution_id' => $institutionId,
            'content' => $data['content'] ?? null,
            'visibility' => $data['visibility'],
            'scheduled_at' => $data['scheduled_at'] ?? null,
        ]);

        foreach (($data['media'] ?? []) as $i => $item) {
            $post->media()->create([
                'type' => $item['type'],
                'url' => $item['url'],
                'thumbnail_url' => $item['thumbnail_url'] ?? null,
                'position' => $i,
            ]);
        }

        $scheduledAt = !empty($data['scheduled_at']) ? \Carbon\Carbon::parse($data['scheduled_at']) : null;
        if (!$scheduledAt || now()->greaterThanOrEqualTo($scheduledAt)) {
            $notificationService->notify(
                $user->id,
                'post',
                'Post published',
                'Your post is now live.',
                ['post_id' => $post->id]
            );
        }

        $this->notifyMentionedUsers(
            actorId: (int) $user->id,
            actorName: (string) $user->name,
            mentionIds: $data['mentions'] ?? [],
            notificationService: $notificationService,
            type: 'post_mention',
            title: 'You were mentioned in a post',
            body: $user->name . ' mentioned you in a post.',
            data: [
                'post_id' => $post->id,
            ]
        );

        return response()->json([
            'message' => 'Post created',
            'post' => new PostResource($post->load([
                'user:id,name,institution_id',
                'user.profile:id,user_id,avatar_url',
                'media',
            ])->loadCount(['comments', 'reactions', 'reports'])),
        ], 201);
    }

    public function scheduled(Request $request)
    {
        $user = $request->user();
        $query = Post::query()
            ->with(['media'])
            ->where('user_id', $user->id)
            ->whereNotNull('scheduled_at')
            ->where('scheduled_at', '>', now())
            ->orderBy('scheduled_at');

        $page = $query->paginate((int) $request->query('per_page', 20));

        return $this->paginatedResponse($page, PostResource::class);
    }

    public function publishNow(Request $request, Post $post, NotificationService $notificationService)
    {
        $actor = $request->user();
        if ((int) $post->user_id !== (int) $actor->id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $now = now();
        $post->update([
            'scheduled_at' => null,
            'scheduled_notified_at' => $now,
            'created_at' => $now,
        ]);

        $notificationService->notify(
            $actor->id,
            'post',
            'Post published',
            'Your scheduled post is now live.',
            ['post_id' => $post->id]
        );

        return response()->json([
            'message' => 'Post published',
            'post' => new PostResource($post->fresh(['user:id,name,institution_id', 'user.profile:id,user_id,avatar_url', 'media'])),
        ]);
    }

    public function show(Request $request, Post $post)
    {
        $viewer = $request->user();
        if (!$this->canViewPost($viewer, $post)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $post = $this->applyViewerFlags($post, $viewer?->id);

        $relations = [
            'user:id,name,email',
            'user.profile:id,user_id,avatar_url',
            'media',
        ];
        if ($this->tableExists('post_comments')) {
            $relations[] = 'comments.user:id,name';
            $relations[] = 'comments.user.profile:id,user_id,avatar_url';
        }

        return response()->json([
            'post' => new PostResource($post->load([
                ...$relations,
            ])->loadCount($this->availablePostCountRelations())),
        ]);
    }

    public function destroy(Request $request, Post $post)
    {
        $actor = $request->user();

        $canDelete = $actor->id === $post->user_id || $this->canModeratePost($actor, $post);
        if (!$canDelete) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $post->delete();

        return response()->json(['message' => 'Post deleted']);
    }

    public function comment(
        PostCommentStoreRequest $request,
        Post $post,
        NotificationService $notificationService
    )
    {
        $actor = $request->user();

        if (!$this->canViewPost($actor, $post)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }
        $data = $request->validated();

        if (!empty($data['parent_id'])) {
            $parentComment = PostComment::find($data['parent_id']);
            if (!$parentComment || (int) $parentComment->post_id !== (int) $post->id) {
                return response()->json(['message' => 'Invalid parent comment for this post'], 422);
            }
        }

        $comment = PostComment::create([
            'post_id' => $post->id,
            'user_id' => $actor->id,
            'content' => $data['content'],
            'parent_id' => $data['parent_id'] ?? null,
        ]);
        $this->updateEngagementScore($post);
        $this->notifyPostOwner(
            actorId: (int) $actor->id,
            actorName: (string) $actor->name,
            post: $post,
            notificationService: $notificationService,
            type: 'post_comment',
            title: 'New comment on your post',
            body: $actor->name . ' commented on your post.',
            data: [
                'comment_id' => $comment->id,
            ],
        );
        if (isset($parentComment) && (int) $parentComment->user_id !== (int) $actor->id) {
            $notificationService->notify(
                (int) $parentComment->user_id,
                'post_comment_reply',
                'New reply to your comment',
                $actor->name . ' replied to your comment.',
                [
                    'post_id' => (int) $post->id,
                    'comment_id' => (int) $comment->id,
                    'parent_comment_id' => (int) $parentComment->id,
                    'from_user_id' => (int) $actor->id,
                ]
            );
        }

        $this->notifyMentionedUsers(
            actorId: (int) $actor->id,
            actorName: (string) $actor->name,
            mentionIds: $data['mentions'] ?? [],
            notificationService: $notificationService,
            type: 'comment_mention',
            title: 'You were mentioned in a comment',
            body: $actor->name . ' mentioned you in a comment.',
            data: [
                'post_id' => (int) $post->id,
                'comment_id' => (int) $comment->id,
            ]
        );

        return response()->json([
            'message' => 'Comment added',
            'comment' => new PostCommentResource(
                $this->applyCommentViewerFlags(
                    $comment->fresh()->load('user:id,name', 'user.profile:id,user_id,avatar_url'),
                    (int) $actor->id
                )->loadCount($this->tableExists('post_comment_reactions') ? ['reactions'] : [])
            ),
        ], 201);
    }

    public function comments(Request $request, Post $post)
    {
        if (!$this->canViewPost($request->user(), $post)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $comments = $post->comments()
            ->with('user:id,name', 'user.profile:id,user_id,avatar_url')
            ->when(
                $this->tableExists('post_comment_reactions'),
                fn ($query) => $query->withCount(['reactions'])
            )
            ->latest()
            ->paginate((int) $request->query('per_page', 30));

        $viewerId = $request->user()?->id;
        $comments->getCollection()->transform(
            fn (PostComment $comment) => $this->applyCommentViewerFlags($comment, $viewerId)
        );

        return $this->paginatedResponse($comments, PostCommentResource::class);
    }

    public function likeComment(
        Request $request,
        PostComment $comment,
        NotificationService $notificationService
    )
    {
        $actor = $request->user();
        $post = $comment->post;

        if (!$post || !$this->canViewPost($actor, $post)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }
        if (!$this->tableExists('post_comment_reactions')) {
            return response()->json(['message' => 'Comment reactions unavailable'], 503);
        }

        PostCommentReaction::query()
            ->where('post_comment_id', $comment->id)
            ->where('user_id', $actor->id)
            ->delete();

        $reaction = PostCommentReaction::create([
            'post_comment_id' => $comment->id,
            'user_id' => $actor->id,
            'type' => 'like',
        ]);

        if ((int) $comment->user_id !== (int) $actor->id) {
            $notificationService->notify(
                (int) $comment->user_id,
                'comment_reaction',
                'Someone liked your comment',
                $actor->name . ' liked your comment.',
                [
                    'post_id' => (int) $comment->post_id,
                    'comment_id' => (int) $comment->id,
                    'reaction_id' => (int) $reaction->id,
                    'reaction_type' => 'like',
                ]
            );
        }

        $comment = $this->applyCommentViewerFlags($comment->fresh(), (int) $actor->id);

        return response()->json([
            'message' => 'Comment liked',
            'comment' => new PostCommentResource(
                $comment->load('user:id,name', 'user.profile:id,user_id,avatar_url')
                    ->loadCount(['reactions'])
            ),
        ]);
    }

    public function unlikeComment(Request $request, PostComment $comment)
    {
        $actor = $request->user();
        $post = $comment->post;

        if (!$post || !$this->canViewPost($actor, $post)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }
        if (!$this->tableExists('post_comment_reactions')) {
            return response()->json(['message' => 'Comment reactions unavailable'], 503);
        }

        PostCommentReaction::query()
            ->where('post_comment_id', $comment->id)
            ->where('user_id', $actor->id)
            ->delete();

        $comment = $this->applyCommentViewerFlags($comment->fresh(), (int) $actor->id);

        return response()->json([
            'message' => 'Comment unliked',
            'comment' => new PostCommentResource(
                $comment->load('user:id,name', 'user.profile:id,user_id,avatar_url')
                    ->loadCount(['reactions'])
            ),
        ]);
    }

    public function like(
        Request $request,
        Post $post,
        NotificationService $notificationService
    )
    {
        $actor = $request->user();

        if (!$this->canViewPost($actor, $post)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $reactionType = (string) $request->input('type', 'like');
        if (!in_array($reactionType, ['like', 'heart', 'clap', 'fire', 'idea'], true)) {
            $reactionType = 'like';
        }

        PostReaction::query()
            ->where('post_id', $post->id)
            ->where('user_id', $actor->id)
            ->delete();

        $reaction = PostReaction::firstOrCreate([
            'post_id' => $post->id,
            'user_id' => $actor->id,
            'type' => $reactionType,
        ]);
        $this->updateEngagementScore($post);
        if ($reaction->wasRecentlyCreated) {
            $this->notifyPostOwner(
                actorId: (int) $actor->id,
                actorName: (string) $actor->name,
                post: $post,
                notificationService: $notificationService,
                type: 'post_reaction',
                title: 'New reaction on your post',
                body: $actor->name . ' reacted to your post.',
                data: [
                    'reaction_id' => $reaction->id,
                    'reaction_type' => $reactionType,
                ],
            );
        }

        $post = $this->applyViewerFlags($post->fresh(), $actor->id);

        return response()->json([
            'message' => 'Post reacted',
            'post' => new PostResource($post->load([
                'user:id,name,institution_id',
                'user.profile:id,user_id,avatar_url',
                'media',
            ])->loadCount($this->availablePostCountRelations())),
        ]);
    }

    public function unlike(Request $request, Post $post)
    {
        PostReaction::query()
            ->where('post_id', $post->id)
            ->where('user_id', $request->user()->id)
            ->delete();
        $this->updateEngagementScore($post);

        $post = $this->applyViewerFlags($post->fresh(), $request->user()->id);

        return response()->json([
            'message' => 'Post reaction removed',
            'post' => new PostResource($post->load([
                'user:id,name,institution_id',
                'user.profile:id,user_id,avatar_url',
                'media',
            ])->loadCount($this->availablePostCountRelations())),
        ]);
    }

    public function report(PostReportRequest $request, Post $post)
    {
        $data = $request->validated();

        PostReport::updateOrCreate(
            ['post_id' => $post->id, 'reported_by' => $request->user()->id],
            ['reason' => $data['reason'] ?? null, 'status' => 'pending']
        );

        return response()->json(['message' => 'Post reported']);
    }

    public function save(Request $request, Post $post)
    {
        PostSave::firstOrCreate([
            'post_id' => $post->id,
            'user_id' => $request->user()->id,
        ]);
        $this->updateEngagementScore($post);

        return response()->json(['message' => 'Post saved']);
    }

    public function repost(Request $request, Post $post, NotificationService $notificationService)
    {
        $actor = $request->user();

        if (!$this->canViewPost($actor, $post)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $repost = PostRepost::firstOrCreate([
            'post_id' => $post->id,
            'user_id' => $actor->id,
        ]);

        if ($repost->wasRecentlyCreated) {
            $this->notifyPostOwner(
                actorId: (int) $actor->id,
                actorName: (string) $actor->name,
                post: $post,
                notificationService: $notificationService,
                type: 'post_repost',
                title: 'Your post was reposted',
                body: $actor->name . ' reposted your post.',
                data: [
                    'repost_id' => $repost->id,
                ],
            );
        }

        return response()->json(['message' => 'Post reposted']);
    }

    public function unrepost(Request $request, Post $post)
    {
        PostRepost::query()
            ->where('post_id', $post->id)
            ->where('user_id', $request->user()->id)
            ->delete();

        return response()->json(['message' => 'Post repost removed']);
    }

    public function share(Request $request, Post $post, NotificationService $notificationService)
    {
        $actor = $request->user();

        if (!$this->canViewPost($actor, $post)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'channel' => ['nullable', 'string', 'max:40'],
        ]);

        $share = PostShare::firstOrCreate(
            [
                'post_id' => $post->id,
                'user_id' => $actor->id,
            ],
            [
                'channel' => $data['channel'] ?? null,
            ]
        );

        if ($share->wasRecentlyCreated) {
            $this->notifyPostOwner(
                actorId: (int) $actor->id,
                actorName: (string) $actor->name,
                post: $post,
                notificationService: $notificationService,
                type: 'post_share',
                title: 'Your post was shared',
                body: $actor->name . ' shared your post.',
                data: [
                    'share_id' => $share->id,
                    'channel' => $share->channel,
                ],
            );
        }

        return response()->json(['message' => 'Post shared']);
    }

    public function unsave(Request $request, Post $post)
    {
        PostSave::where('post_id', $post->id)
            ->where('user_id', $request->user()->id)
            ->delete();
        $this->updateEngagementScore($post);

        return response()->json(['message' => 'Post unsaved']);
    }

    public function hide(Request $request, Post $post)
    {
        PostHide::firstOrCreate([
            'post_id' => $post->id,
            'user_id' => $request->user()->id,
        ]);

        return response()->json(['message' => 'Post hidden']);
    }

    public function unhide(Request $request, Post $post)
    {
        PostHide::where('post_id', $post->id)
            ->where('user_id', $request->user()->id)
            ->delete();

        return response()->json(['message' => 'Post unhidden']);
    }

    public function pin(Request $request, Post $post)
    {
        $actor = $request->user();

        if (!$this->canModeratePost($actor, $post)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $post->update([
            'is_pinned' => true,
            'pinned_at' => now(),
            'pinned_by' => $actor->id,
        ]);

        return response()->json(['message' => 'Post pinned']);
    }

    public function unpin(Request $request, Post $post)
    {
        $actor = $request->user();

        if (!$this->canModeratePost($actor, $post)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $post->update([
            'is_pinned' => false,
            'pinned_at' => null,
            'pinned_by' => null,
        ]);

        return response()->json(['message' => 'Post unpinned']);
    }

    private function canViewPost($viewer, Post $post): bool
    {
        if (!$viewer) {
            if ($post->scheduled_at && $post->scheduled_at->isFuture()) {
                return false;
            }

            return $post->visibility === 'public';
        }

        if ((int) $post->user_id === (int) $viewer->id) {
            return true;
        }

        if ($viewer->role === 'super_admin') {
            return true;
        }

        if ($post->scheduled_at && $post->scheduled_at->isFuture()) {
            return (int) $post->user_id === (int) $viewer->id;
        }

        if ($post->visibility === 'public') {
            return true;
        }

        return $viewer->institution_id && (int) $viewer->institution_id === (int) $post->institution_id;
    }

    private function canModeratePost($actor, Post $post): bool
    {
        if ($actor->role === 'super_admin') {
            return true;
        }

        if ($actor->role === 'institution_admin' || $actor->role === 'admin') {
            return $actor->institution_id && (int) $actor->institution_id === (int) $post->institution_id;
        }

        return false;
    }

    private function updateEngagementScore(Post $post): void
    {
        $reactions = $this->tableExists('post_reactions') ? $post->reactions()->count() : 0;
        $comments = $this->tableExists('post_comments') ? $post->comments()->count() : 0;
        $saves = $this->tableExists('post_saves') ? $post->saves()->count() : 0;

        $score = ($reactions * 1) + ($comments * 2) + ($saves * 3);

        $post->update([
            'engagement_score' => $score,
            'ai_rank_score' => $score,
        ]);
    }

    private function notifyPostOwner(
        int $actorId,
        string $actorName,
        Post $post,
        NotificationService $notificationService,
        string $type,
        string $title,
        ?string $body,
        array $data = []
    ): void {
        if ((int) $post->user_id === $actorId) {
            return;
        }

        $notificationService->notify(
            (int) $post->user_id,
            $type,
            $title,
            $body,
            array_merge($data, [
                'post_id' => $post->id,
                'from_user_id' => $actorId,
                'from_user_name' => $actorName,
            ])
        );
    }

    private function notifyMentionedUsers(
        int $actorId,
        string $actorName,
        array $mentionIds,
        NotificationService $notificationService,
        string $type,
        string $title,
        ?string $body,
        array $data = []
    ): void {
        $allowedIds = $this->filterMentionableUserIds($actorId, $mentionIds);

        foreach ($allowedIds as $mentionedUserId) {
            $notificationService->notify(
                $mentionedUserId,
                $type,
                $title,
                $body,
                array_merge($data, [
                    'from_user_id' => $actorId,
                    'from_user_name' => $actorName,
                    'mentioned_user_id' => $mentionedUserId,
                ])
            );
        }
    }

    private function filterMentionableUserIds(int $actorId, array $mentionIds): array
    {
        $candidateIds = collect($mentionIds)
            ->map(fn ($id) => is_numeric($id) ? (int) $id : null)
            ->filter()
            ->reject(fn (int $id) => $id === $actorId)
            ->unique()
            ->values();

        if ($candidateIds->isEmpty()) {
            return [];
        }

        return ConnectionRequest::query()
            ->where('status', 'accepted')
            ->where(function ($query) use ($actorId, $candidateIds) {
                $query
                    ->where(function ($sub) use ($actorId, $candidateIds) {
                        $sub->where('from_user_id', $actorId)
                            ->whereIn('to_user_id', $candidateIds->all());
                    })
                    ->orWhere(function ($sub) use ($actorId, $candidateIds) {
                        $sub->whereIn('from_user_id', $candidateIds->all())
                            ->where('to_user_id', $actorId);
                    });
            })
            ->get()
            ->flatMap(function (ConnectionRequest $connection) use ($actorId) {
                return [
                    (int) $connection->from_user_id === $actorId
                        ? (int) $connection->to_user_id
                        : (int) $connection->from_user_id,
                ];
            })
            ->unique()
            ->values()
            ->all();
    }

    private function availablePostCountRelations(): array
    {
        $relations = [];
        if ($this->tableExists('post_comments')) {
            $relations[] = 'comments';
        }
        if ($this->tableExists('post_reactions')) {
            $relations[] = 'reactions';
        }
        if ($this->tableExists('post_reports')) {
            $relations[] = 'reports';
        }
        return $relations;
    }

    private function accessibleInstitutionIdsForUser(User $user): array
    {
        $ids = [];
        if ($user->institution_id) {
            $ids[] = (int) $user->institution_id;
        }

        $membershipIds = InstitutionMembership::query()
            ->where('user_id', $user->id)
            ->where('status', 'approved')
            ->pluck('institution_id')
            ->map(fn ($id) => (int) $id)
            ->all();

        return array_values(array_unique([...$ids, ...$membershipIds]));
    }

    private function applyViewerFlags(Post $post, ?int $viewerId): Post
    {
        $reactionType = null;
        if ($viewerId && $this->tableExists('post_reactions')) {
            $reactionType = $post->reactions()
                ->where('user_id', $viewerId)
                ->value('type');
        }
        $post->setAttribute(
            'is_saved',
            $viewerId && $this->tableExists('post_saves')
                ? $post->saves()->where('user_id', $viewerId)->exists()
                : false
        );
        $post->setAttribute(
            'is_liked',
            !empty($reactionType)
        );
        $post->setAttribute('user_reaction', $reactionType);

        return $post;
    }

    private function applyCommentViewerFlags(PostComment $comment, ?int $viewerId): PostComment
    {
        $reactionType = null;
        if ($viewerId && $this->tableExists('post_comment_reactions')) {
            $reactionType = $comment->reactions()
                ->where('user_id', $viewerId)
                ->value('type');
        }

        $comment->setAttribute('is_liked', !empty($reactionType));
        $comment->setAttribute('user_reaction', $reactionType);

        return $comment;
    }

    private function tableExists(string $table): bool
    {
        if (!array_key_exists($table, $this->tableExistsCache)) {
            $this->tableExistsCache[$table] = Schema::hasTable($table);
        }

        return $this->tableExistsCache[$table];
    }
}
