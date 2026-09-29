<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\AdServeRequest;
use App\Http\Requests\Api\AdStoreRequest;
use App\Http\Requests\Api\AdUpdateRequest;
use App\Http\Resources\Api\AdResource;
use App\Models\AuditLog;
use App\Models\Ad;
use App\Models\AdClick;
use App\Models\AdImpression;
use App\Models\HiddenAd;
use App\Models\UserNotification;
use Carbon\Carbon;
use Illuminate\Http\Request;

class AdController extends Controller
{
    private function calculateSpend(string $pricingModel, float $price, int $impressions, int $clicks): float
    {
        if ($pricingModel === 'cpc') {
            return $clicks * $price;
        }
        if ($pricingModel === 'cpm') {
            return ($impressions / 1000) * $price;
        }
        if ($pricingModel === 'flat') {
            return ($impressions > 0 || $clicks > 0) ? $price : 0;
        }
        return 0;
    }

    public function index(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $ads = Ad::query()
            ->with(['advertiser:id,name,email,institution_id', 'institution:id,name,slug,status'])
            ->withCount(['impressions', 'clicks'])
            ->when($actor->role === 'institution_admin', function ($q) use ($actor) {
                $q->where('institution_id', $actor->institution_id);
            })
            ->when($actor->role === 'super_admin' && $request->filled('institution_id'), function ($q) use ($request) {
                $q->where('institution_id', $request->query('institution_id'));
            })
            ->when($request->filled('status'), fn($q) => $q->where('status', $request->query('status')))
            ->when($request->filled('placement'), fn($q) => $q->where('placement', $request->query('placement')))
            ->when($request->filled('search'), function ($q) use ($request) {
                $search = $request->query('search');
                $q->where('title', 'like', '%' . $search . '%');
            })
            ->latest()
            ->paginate((int) $request->query('per_page', 20));

        return $this->paginatedResponse($ads, AdResource::class);
    }

    public function store(AdStoreRequest $request)
    {
        $data = $request->validated();

        $ad = Ad::create([
            'advertiser_id' => $request->user()->id,
            'institution_id' => $data['institution_id'] ?? $request->user()->institution_id,
            'title' => $data['title'],
            'content' => $data['content'] ?? null,
            'media_url' => $data['media_url'] ?? null,
            'target_url' => $data['target_url'] ?? null,
            'placement' => $data['placement'],
            'pricing_model' => $data['pricing_model'],
            'objective' => $data['objective'] ?? 'traffic',
            'price' => $data['price'],
            'budget' => $data['budget'],
            'daily_budget' => $data['daily_budget'] ?? null,
            'daily_cap_enabled' => (bool) ($data['daily_cap_enabled'] ?? false),
            'currency' => strtoupper($data['currency']),
            'target_institution_id' => $data['target_institution_id'] ?? null,
            'target_location' => $data['target_location'] ?? null,
            'target_interests' => $data['target_interests'] ?? [],
            'status' => 'active',
            'starts_at' => $data['starts_at'] ?? now(),
            'ends_at' => $data['ends_at'] ?? null,
        ]);

        AuditLog::record($request->user(), 'ad.created', Ad::class, $ad->id, [
            'placement' => $ad->placement,
            'status' => $ad->status,
        ], $request);

        return response()->json([
            'message' => 'Ad created',
            'ad' => new AdResource($ad),
        ], 201);
    }

    public function update(AdUpdateRequest $request, Ad $ad)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $ad->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();
        if (isset($data['currency'])) {
            $data['currency'] = strtoupper($data['currency']);
        }

        $ad->update($data);

        AuditLog::record($actor, 'ad.updated', Ad::class, $ad->id, [
            'status' => $ad->status,
        ], $request);

        return response()->json([
            'message' => 'Ad updated',
            'ad' => new AdResource($ad->fresh()->loadCount(['impressions', 'clicks'])),
        ]);
    }

    public function destroy(Request $request, Ad $ad)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $ad->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $ad->delete();

        AuditLog::record($actor, 'ad.deleted', Ad::class, $ad->id, [], $request);

        return response()->json(['message' => 'Ad removed']);
    }

    public function serve(AdServeRequest $request)
    {
        $viewer = $request->user();
        $data = $request->validated();

        $hiddenIds = HiddenAd::query()
            ->where('user_id', $viewer->id)
            ->pluck('ad_id')
            ->all();

        $query = Ad::query()
            ->where('status', 'active')
            ->where('placement', $data['placement'])
            ->when(!empty($hiddenIds), function ($q) use ($hiddenIds) {
                $q->whereNotIn('id', $hiddenIds);
            })
            ->where(function ($q) {
                $q->whereNull('starts_at')->orWhere('starts_at', '<=', now());
            })
            ->where(function ($q) {
                $q->whereNull('ends_at')->orWhere('ends_at', '>=', now());
            });

        $targetInstitutionId = $data['institution_id'] ?? $viewer->institution_id;
        if ($targetInstitutionId) {
            $query->where(function ($q) use ($targetInstitutionId) {
                $q->whereNull('target_institution_id')
                    ->orWhere('target_institution_id', $targetInstitutionId);
            });
        }

        if (!empty($data['location'])) {
            $query->where(function ($q) use ($data) {
                $q->whereNull('target_location')
                    ->orWhere('target_location', 'like', '%' . $data['location'] . '%');
            });
        }

        if (!empty($data['interests'])) {
            foreach ($data['interests'] as $interest) {
                $query->where(function ($q) use ($interest) {
                    $q->whereNull('target_interests')
                        ->orWhereJsonContains('target_interests', $interest);
                });
            }
        }

        $candidates = $query->inRandomOrder()->limit(25)->get();
        $ad = null;
        foreach ($candidates as $candidate) {
            $totalImpressions = AdImpression::where('ad_id', $candidate->id)->count();
            $totalClicks = AdClick::where('ad_id', $candidate->id)->count();
            $totalSpend = $this->calculateSpend(
                (string) $candidate->pricing_model,
                (float) $candidate->price,
                (int) $totalImpressions,
                (int) $totalClicks
            );
            if ($candidate->budget && !$candidate->budget_alerted_at) {
                $threshold = (float) $candidate->budget * 0.9;
                if ($totalSpend >= $threshold) {
                    UserNotification::create([
                        'user_id' => $candidate->advertiser_id,
                        'type' => 'ad_budget_alert',
                        'title' => 'Ad budget at 90%',
                        'body' => "Your ad '{$candidate->title}' has reached 90% of its budget.",
                        'data' => [
                            'ad_id' => $candidate->id,
                            'budget' => (float) $candidate->budget,
                            'spend' => round($totalSpend, 2),
                            'percent' => 90,
                        ],
                        'send_push' => false,
                        'send_email' => false,
                    ]);
                    $candidate->budget_alerted_at = now();
                    $candidate->save();
                }
            }
            if ($candidate->budget && $totalSpend >= (float) $candidate->budget) {
                $candidate->status = 'ended';
                $candidate->save();
                continue;
            }
            if ($candidate->daily_cap_enabled && $candidate->daily_budget) {
                $todayImpressions = AdImpression::where('ad_id', $candidate->id)
                    ->whereDate('viewed_at', now()->toDateString())
                    ->count();
                $todayClicks = AdClick::where('ad_id', $candidate->id)
                    ->whereDate('clicked_at', now()->toDateString())
                    ->count();
                $todaySpend = $this->calculateSpend(
                    (string) $candidate->pricing_model,
                    (float) $candidate->price,
                    (int) $todayImpressions,
                    (int) $todayClicks
                );
                if ($todaySpend >= (float) $candidate->daily_budget) {
                    continue;
                }
            }
            $ad = $candidate;
            break;
        }
        if (!$ad) {
            return response()->json(['data' => null]);
        }

        AdImpression::create([
            'ad_id' => $ad->id,
            'user_id' => $viewer->id,
            'placement' => $data['placement'],
            'viewed_at' => now(),
        ]);

        return response()->json(['data' => new AdResource($ad)]);
    }

    public function click(Request $request, Ad $ad)
    {
        AdClick::create([
            'ad_id' => $ad->id,
            'user_id' => $request->user()->id,
            'clicked_at' => now(),
        ]);

        return response()->json(['message' => 'Ad click recorded']);
    }

    public function analytics(Ad $ad)
    {
        $from = request()->filled('from')
            ? Carbon::parse(request()->query('from'))->startOfDay()
            : now()->subDays(30)->startOfDay();
        $to = request()->filled('to')
            ? Carbon::parse(request()->query('to'))->endOfDay()
            : now()->endOfDay();

        $impressionsQuery = AdImpression::where('ad_id', $ad->id)
            ->whereBetween('viewed_at', [$from, $to]);
        $clicksQuery = AdClick::where('ad_id', $ad->id)
            ->whereBetween('clicked_at', [$from, $to]);
        $impressions = (clone $impressionsQuery)->count();
        $clicks = (clone $clicksQuery)->count();
        $ctr = $impressions > 0 ? round(($clicks / $impressions) * 100, 2) : 0;
        $spend = $this->calculateSpend((string) $ad->pricing_model, (float) $ad->price, (int) $impressions, (int) $clicks);
        $budgetRemaining = $ad->budget !== null ? max(0, (float) $ad->budget - $spend) : null;

        $impressionsSeries = (clone $impressionsQuery)
            ->selectRaw('DATE(viewed_at) as date, COUNT(*) as total')
            ->groupBy('date')
            ->orderBy('date')
            ->get()
            ->keyBy('date');
        $clicksSeries = (clone $clicksQuery)
            ->selectRaw('DATE(clicked_at) as date, COUNT(*) as total')
            ->groupBy('date')
            ->orderBy('date')
            ->get()
            ->keyBy('date');

        $dates = collect(array_unique(array_merge(
            $impressionsSeries->keys()->all(),
            $clicksSeries->keys()->all()
        )))->sort()->values();

        $series = $dates->map(function ($date) use ($impressionsSeries, $clicksSeries) {
            return [
                'date' => $date,
                'impressions' => (int) ($impressionsSeries[$date]->total ?? 0),
                'clicks' => (int) ($clicksSeries[$date]->total ?? 0),
            ];
        })->values();

        $todayImpressions = AdImpression::where('ad_id', $ad->id)
            ->whereDate('viewed_at', now()->toDateString())
            ->count();
        $todayClicks = AdClick::where('ad_id', $ad->id)
            ->whereDate('clicked_at', now()->toDateString())
            ->count();
        $todaySpend = $this->calculateSpend((string) $ad->pricing_model, (float) $ad->price, (int) $todayImpressions, (int) $todayClicks);

        return response()->json([
            'ad' => new AdResource($ad->loadCount(['impressions', 'clicks'])),
            'stats' => [
                'impressions' => $impressions,
                'clicks' => $clicks,
                'ctr_percent' => $ctr,
                'spend' => round($spend, 2),
                'budget_remaining' => $budgetRemaining,
                'daily_budget' => $ad->daily_budget,
                'daily_spend' => round($todaySpend, 2),
            ],
            'series' => $series,
            'range' => [
                'from' => $from->toDateString(),
                'to' => $to->toDateString(),
            ],
        ]);
    }

    public function analyticsSummary(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $from = $request->filled('from')
            ? Carbon::parse($request->query('from'))->startOfDay()
            : now()->subDays(30)->startOfDay();
        $to = $request->filled('to')
            ? Carbon::parse($request->query('to'))->endOfDay()
            : now()->endOfDay();

        $adsQuery = Ad::query()
            ->when($actor->role === 'institution_admin', function ($q) use ($actor) {
                $q->where('institution_id', $actor->institution_id);
            })
            ->when($actor->role === 'super_admin' && $request->filled('institution_id'), function ($q) use ($request) {
                $q->where('institution_id', $request->query('institution_id'));
            })
            ->when($request->filled('status'), fn($q) => $q->where('status', $request->query('status')))
            ->when($request->filled('placement'), fn($q) => $q->where('placement', $request->query('placement')));

        $ads = $adsQuery->get(['id', 'pricing_model', 'price', 'budget', 'currency', 'status', 'placement']);
        if ($ads->isEmpty()) {
            return response()->json([
                'summary' => [
                    'ads_total' => 0,
                    'ads_active' => 0,
                    'impressions' => 0,
                    'clicks' => 0,
                    'ctr_percent' => 0,
                    'spend_total' => 0,
                    'spend_by_currency' => [],
                    'budget_total' => 0,
                    'budget_remaining' => 0,
                ],
                'breakdowns' => [
                    'placements' => [],
                    'pricing_models' => [],
                ],
                'series' => [],
                'range' => [
                    'from' => $from->toDateString(),
                    'to' => $to->toDateString(),
                ],
            ]);
        }

        $adIds = $ads->pluck('id');
        $impressionsQuery = AdImpression::whereIn('ad_id', $adIds)
            ->whereBetween('viewed_at', [$from, $to]);
        $clicksQuery = AdClick::whereIn('ad_id', $adIds)
            ->whereBetween('clicked_at', [$from, $to]);

        $totalImpressions = (clone $impressionsQuery)->count();
        $totalClicks = (clone $clicksQuery)->count();
        $ctr = $totalImpressions > 0 ? round(($totalClicks / $totalImpressions) * 100, 2) : 0;

        $impressionsByAd = (clone $impressionsQuery)
            ->selectRaw('ad_id, COUNT(*) as total')
            ->groupBy('ad_id')
            ->pluck('total', 'ad_id');
        $clicksByAd = (clone $clicksQuery)
            ->selectRaw('ad_id, COUNT(*) as total')
            ->groupBy('ad_id')
            ->pluck('total', 'ad_id');

        $spendByCurrency = [];
        $budgetTotal = 0;
        $budgetRemaining = 0;

        foreach ($ads as $ad) {
            $impressions = (int) ($impressionsByAd[$ad->id] ?? 0);
            $clicks = (int) ($clicksByAd[$ad->id] ?? 0);
            $price = (float) ($ad->price ?? 0);
            $spend = 0;

            if ($ad->pricing_model === 'cpc') {
                $spend = $clicks * $price;
            } elseif ($ad->pricing_model === 'cpm') {
                $spend = ($impressions / 1000) * $price;
            } elseif ($ad->pricing_model === 'flat') {
                $spend = ($impressions > 0 || $clicks > 0) ? $price : 0;
            }

            $currency = strtoupper($ad->currency ?? 'USD');
            $spendByCurrency[$currency] = round(($spendByCurrency[$currency] ?? 0) + $spend, 2);
            $budgetTotal += (float) ($ad->budget ?? 0);
            $budgetRemaining += max(0, (float) ($ad->budget ?? 0) - $spend);
        }

        $spendTotal = array_sum($spendByCurrency);
        $placements = $ads->groupBy('placement')->map->count();
        $pricingModels = $ads->groupBy('pricing_model')->map->count();

        $impressionsSeries = (clone $impressionsQuery)
            ->selectRaw('DATE(viewed_at) as date, COUNT(*) as total')
            ->groupBy('date')
            ->orderBy('date')
            ->get()
            ->keyBy('date');
        $clicksSeries = (clone $clicksQuery)
            ->selectRaw('DATE(clicked_at) as date, COUNT(*) as total')
            ->groupBy('date')
            ->orderBy('date')
            ->get()
            ->keyBy('date');

        $dates = collect(array_unique(array_merge(
            $impressionsSeries->keys()->all(),
            $clicksSeries->keys()->all()
        )))->sort()->values();

        $series = $dates->map(function ($date) use ($impressionsSeries, $clicksSeries) {
            return [
                'date' => $date,
                'impressions' => (int) ($impressionsSeries[$date]->total ?? 0),
                'clicks' => (int) ($clicksSeries[$date]->total ?? 0),
            ];
        })->values();

        return response()->json([
            'summary' => [
                'ads_total' => $ads->count(),
                'ads_active' => $ads->where('status', 'active')->count(),
                'impressions' => $totalImpressions,
                'clicks' => $totalClicks,
                'ctr_percent' => $ctr,
                'spend_total' => round($spendTotal, 2),
                'spend_by_currency' => $spendByCurrency,
                'budget_total' => round($budgetTotal, 2),
                'budget_remaining' => round($budgetRemaining, 2),
            ],
            'breakdowns' => [
                'placements' => $placements,
                'pricing_models' => $pricingModels,
            ],
            'series' => $series,
            'range' => [
                'from' => $from->toDateString(),
                'to' => $to->toDateString(),
            ],
        ]);
    }

    public function hide(Request $request, Ad $ad)
    {
        HiddenAd::firstOrCreate([
            'user_id' => $request->user()->id,
            'ad_id' => $ad->id,
        ]);

        return response()->json(['message' => 'Ad hidden']);
    }

    public function hidden(Request $request)
    {
        $ids = HiddenAd::query()
            ->where('user_id', $request->user()->id)
            ->pluck('ad_id');

        return response()->json(['data' => $ids]);
    }
}
