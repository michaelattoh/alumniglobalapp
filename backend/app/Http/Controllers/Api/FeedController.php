<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\AnnouncementResource;
use App\Http\Resources\Api\PostResource;
use App\Models\Announcement;
use App\Models\AiControl;
use App\Models\NotificationPreference;
use App\Models\Post;
use App\Models\Recommendation;
use App\Models\SystemSetting;
use Illuminate\Http\Request;

class FeedController extends Controller
{
    public function global(Request $request)
    {
        return $this->buildFeed($request, null);
    }

    public function institution(Request $request, int $institutionId)
    {
        return $this->buildFeed($request, $institutionId);
    }

    private function buildFeed(Request $request, ?int $institutionId)
    {
        $viewer = $request->user();
        $sort = $request->query('sort', 'chrono'); // chrono|relevance|ai
        $aiControl = AiControl::first();
        if ($sort === 'ai') {
            if ($aiControl && !$aiControl->feed_personalization_enabled) {
                $sort = 'relevance';
            }
            $aiEnabled = SystemSetting::query()->where('key', 'ai_enabled')->value('value');
            if ($aiEnabled === false || $aiEnabled === 0 || $aiEnabled === '0' || $aiEnabled === 'false') {
                $sort = 'relevance';
            }
            $pref = NotificationPreference::query()->where('user_id', $viewer->id)->value('ai_personalization_enabled');
            if ($pref === false) {
                $sort = 'relevance';
            }
        }

        $posts = Post::query()
            ->with([
                'user:id,name,institution_id',
                'user.profile:id,user_id,avatar_url',
                'media:id,post_id,type,url,thumbnail_url,position',
            ])
            ->withCount(['comments', 'reactions', 'reports']);
        $posts->where(function ($q) {
            $q->whereNull('scheduled_at')
              ->orWhere('scheduled_at', '<=', now());
        });

        if ($institutionId) {
            $posts->where('institution_id', $institutionId);
        }

        if ($viewer->role !== 'super_admin') {
            $posts->where(function ($q) use ($viewer, $institutionId) {
                if ($institutionId) {
                    $q->where(function ($i) use ($viewer, $institutionId) {
                        $i->where('visibility', 'public')
                            ->where('institution_id', $institutionId);

                        if ($viewer->institution_id === $institutionId) {
                            $i->orWhere(function ($same) use ($institutionId) {
                                $same->where('visibility', 'institution_only')
                                    ->where('institution_id', $institutionId);
                            });
                        }
                    });

                    return;
                }

                $q->where('visibility', 'public');
                if ($viewer->institution_id) {
                    $q->orWhere(function ($private) use ($viewer) {
                        $private->where('visibility', 'institution_only')
                            ->where('institution_id', $viewer->institution_id);
                    });
                }
                $q->orWhere('user_id', $viewer->id);
            });
        }

        if ($sort === 'relevance') {
            $posts->orderByDesc('is_pinned')
                ->orderByDesc('engagement_score')
                ->orderByDesc('created_at');
        } elseif ($sort === 'ai') {
            $posts->orderByDesc('is_pinned')
                ->orderByRaw("COALESCE((SELECT score FROM recommendations WHERE recommendations.user_id = ? AND recommendations.type = 'content' AND recommendations.entity_type = 'post' AND recommendations.entity_id = posts.id LIMIT 1), ai_rank_score, engagement_score) DESC", [$viewer->id])
                ->orderByDesc('created_at');
        } else {
            $posts->orderByDesc('is_pinned')
                ->latest();
        }

        $announcements = Announcement::query()
            ->with(['creator:id,name,email,institution_id', 'institution'])
            ->where('is_active', true)
            ->where(function ($q) use ($institutionId, $viewer) {
                $q->where('audience', 'global');

                $targetInstitution = $institutionId ?? $viewer->institution_id;
                if ($targetInstitution) {
                    $q->orWhere(function ($i) use ($targetInstitution) {
                        $i->where('audience', 'institution')
                            ->where('institution_id', $targetInstitution);
                    });
                }
            })
            ->where(function ($q) {
                $q->whereNull('starts_at')->orWhere('starts_at', '<=', now());
            })
            ->where(function ($q) {
                $q->whereNull('ends_at')->orWhere('ends_at', '>=', now());
            })
            ->latest()
            ->limit(10)
            ->get();

        $postPaginator = $posts->paginate((int) $request->query('per_page', 20));

        if ($sort === 'ai') {
            $postIds = collect($postPaginator->items())->pluck('id')->all();
            if (!empty($postIds)) {
                Recommendation::query()
                    ->where('user_id', $viewer->id)
                    ->where('type', 'content')
                    ->where('entity_type', 'post')
                    ->whereIn('entity_id', $postIds)
                    ->whereNull('served_at')
                    ->update(['served_at' => now()]);
            }
        }

        return response()->json([
            'sort' => $sort,
            'announcements' => $this->collectionResponse($announcements, AnnouncementResource::class),
            'posts' => [
                'data' => PostResource::collection(collect($postPaginator->items()))->resolve(),
                'meta' => $this->paginationMeta($postPaginator),
            ],
        ]);
    }
}
