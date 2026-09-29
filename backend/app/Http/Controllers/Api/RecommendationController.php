<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\AiControlUpdateRequest;
use App\Http\Requests\Api\RecommendationFeedbackRequest;
use App\Http\Resources\Api\AiControlResource;
use App\Http\Resources\Api\RecommendationResource;
use App\Models\AiControl;
use App\Models\Event;
use App\Models\Post;
use App\Models\Recommendation;
use App\Models\RecommendationIgnore;
use App\Models\User;
use App\Services\RecommendationService;
use Illuminate\Http\Request;

class RecommendationController extends Controller
{
    public function index(Request $request, RecommendationService $recommendationService)
    {
        $user = $request->user();
        $type = $request->query('type', 'content');
        $perPage = (int) $request->query('per_page', 20);

        $shouldRefresh = Recommendation::query()
            ->where('user_id', $user->id)
            ->where('type', $type)
            ->latest('updated_at')
            ->value('updated_at');

        if (!$shouldRefresh || now()->diffInHours($shouldRefresh) >= 6) {
            $recommendationService->refresh($user, $type, $perPage);
        }

        $query = Recommendation::query()
            ->where('user_id', $user->id)
            ->where('type', $type)
            ->orderByDesc('score');

        if ($query->count() === 0) {
            $recommendationService->generate($user, $type, $perPage);
        }

        $recs = Recommendation::query()
            ->where('user_id', $user->id)
            ->where('type', $type)
            ->orderByDesc('score')
            ->paginate($perPage);

        Recommendation::where('user_id', $user->id)
            ->where('type', $type)
            ->whereNull('served_at')
            ->whereIn('id', collect($recs->items())->pluck('id')->all())
            ->update(['served_at' => now()]);

        $data = $this->attachEntities(collect($recs->items()));

        return response()->json([
            'data' => $data,
            'meta' => $this->paginationMeta($recs),
        ]);
    }

    public function feedback(RecommendationFeedbackRequest $request, Recommendation $recommendation)
    {
        if ((int) $recommendation->user_id !== (int) $request->user()->id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();

        if ($data['action'] === 'clicked') {
            $recommendation->update(['clicked_at' => now()]);
        }
        if ($data['action'] === 'dismissed') {
            RecommendationIgnore::firstOrCreate([
                'user_id' => $recommendation->user_id,
                'entity_type' => $recommendation->entity_type,
                'entity_id' => $recommendation->entity_id,
            ]);
            $recommendation->delete();
        }

        return response()->json(['message' => 'Feedback recorded']);
    }

    public function controls(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $control = AiControl::firstOrCreate([], [
            'feed_personalization_enabled' => true,
            'recommendations_enabled' => true,
            'max_daily_recommendations' => 100,
            'guardrails' => [],
            'updated_by' => $actor->id,
        ]);

        return response()->json(['data' => new AiControlResource($control)]);
    }

    public function updateControls(AiControlUpdateRequest $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $control = AiControl::firstOrCreate([], [
            'feed_personalization_enabled' => true,
            'recommendations_enabled' => true,
            'max_daily_recommendations' => 100,
            'guardrails' => [],
            'updated_by' => $actor->id,
        ]);

        $control->update(array_merge($request->validated(), ['updated_by' => $actor->id]));

        return response()->json(['message' => 'AI controls updated', 'data' => new AiControlResource($control->fresh())]);
    }

    public function performance(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $total = Recommendation::count();
        $clicked = Recommendation::whereNotNull('clicked_at')->count();
        $served = Recommendation::whereNotNull('served_at')->count();

        $byType = Recommendation::query()
            ->selectRaw('type, COUNT(*) as total, SUM(clicked_at IS NOT NULL) as clicked')
            ->groupBy('type')
            ->get()
            ->mapWithKeys(function ($row) {
                $ctr = $row->total > 0 ? round(($row->clicked / $row->total) * 100, 2) : 0;
                return [$row->type => ['total' => (int) $row->total, 'clicked' => (int) $row->clicked, 'ctr' => $ctr]];
            });

        return response()->json([
            'stats' => [
                'recommendations_total' => $total,
                'recommendations_clicked' => $clicked,
                'recommendations_served' => $served,
                'ctr_percent' => $total > 0 ? round(($clicked / $total) * 100, 2) : 0,
                'by_type' => $byType,
            ],
        ]);
    }

    private function attachEntities($recommendations): array
    {
        $postIds = $recommendations->where('entity_type', 'post')->pluck('entity_id')->all();
        $eventIds = $recommendations->where('entity_type', 'event')->pluck('entity_id')->all();
        $userIds = $recommendations->where('entity_type', 'user')->pluck('entity_id')->all();

        $posts = Post::query()
            ->with(['user:id,name,institution_id', 'media:id,post_id,type,url,thumbnail_url,position'])
            ->withCount(['comments', 'reactions', 'reports'])
            ->whereIn('id', $postIds)
            ->get()
            ->keyBy('id');

        $events = Event::query()
            ->with('creator:id,name')
            ->whereIn('id', $eventIds)
            ->get()
            ->keyBy('id');

        $users = User::query()
            ->with('profile')
            ->whereIn('id', $userIds)
            ->get()
            ->keyBy('id');

        return $recommendations->map(function ($rec) use ($posts, $events, $users) {
            $payload = (new RecommendationResource($rec))->resolve();
            if ($rec->entity_type === 'post') {
                $payload['entity'] = optional($posts->get($rec->entity_id))->toArray();
            } elseif ($rec->entity_type === 'event') {
                $payload['entity'] = optional($events->get($rec->entity_id))->toArray();
            } elseif ($rec->entity_type === 'user') {
                $payload['entity'] = optional($users->get($rec->entity_id))->toArray();
            }
            return $payload;
        })->values()->all();
    }
}
