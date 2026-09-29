<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnalyticsEvent;
use App\Models\Donation;
use App\Models\Event;
use App\Models\EventRsvp;
use App\Models\Institution;
use App\Models\InstitutionMembership;
use App\Models\PaymentTransaction;
use App\Models\Profile;
use App\Models\Post;
use App\Models\Story;
use App\Models\User;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class AnalyticsController extends Controller
{
    public function track(Request $request)
    {
        $data = $request->validate([
            'event_type' => ['required', 'string', 'max:80'],
            'entity_type' => ['nullable', 'string', 'max:80'],
            'entity_id' => ['nullable', 'integer'],
            'value' => ['nullable', 'numeric'],
            'metadata' => ['nullable', 'array'],
            'institution_id' => ['nullable', 'integer', 'exists:institutions,id'],
        ]);

        $event = AnalyticsEvent::create([
            'user_id' => $request->user()->id,
            'institution_id' => $data['institution_id'] ?? $request->user()->institution_id,
            'event_type' => $data['event_type'],
            'entity_type' => $data['entity_type'] ?? null,
            'entity_id' => $data['entity_id'] ?? null,
            'value' => $data['value'] ?? null,
            'metadata' => $data['metadata'] ?? [],
            'occurred_at' => now(),
        ]);

        return response()->json(['message' => 'Event tracked', 'data' => $event], 201);
    }

    public function institution(Request $request, Institution $institution)
    {
        $actor = $request->user();
        $canView = $actor->role === 'super_admin' || ((int) $actor->institution_id === (int) $institution->id && in_array($actor->role, ['institution_admin', 'super_admin'], true));
        if (!$canView) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $from = $request->query('from');
        $to = $request->query('to');
        $hasRange = $request->filled('from') || $request->filled('to');
        $cacheKey = sprintf(
            'analytics:institution:%d:%s:%s',
            $institution->id,
            $from ?: 'none',
            $to ?: 'none'
        );

        $payload = Cache::remember($cacheKey, now()->addMinutes(5), function () use ($institution, $from, $to, $hasRange) {
            $userQuery = User::where('institution_id', $institution->id);
            $postQuery = Post::where('institution_id', $institution->id);
            $storyQuery = Story::where('institution_id', $institution->id);
            $eventQuery = Event::where('institution_id', $institution->id);
            if ($from) {
                $userQuery->whereDate('created_at', '>=', $from);
                $postQuery->whereDate('created_at', '>=', $from);
                $storyQuery->whereDate('created_at', '>=', $from);
                $eventQuery->whereDate('created_at', '>=', $from);
            }
            if ($to) {
                $userQuery->whereDate('created_at', '<=', $to);
                $postQuery->whereDate('created_at', '<=', $to);
                $storyQuery->whereDate('created_at', '<=', $to);
                $eventQuery->whereDate('created_at', '<=', $to);
            }

            $donationQuery = Donation::whereHas('campaign', function ($q) use ($institution) {
                $q->where('institution_id', $institution->id);
            })->where('status', 'success');
            if ($from) {
                $donationQuery->whereDate('created_at', '>=', $from);
            }
            if ($to) {
                $donationQuery->whereDate('created_at', '<=', $to);
            }

            $engagementQuery = AnalyticsEvent::where('institution_id', $institution->id);
            if ($hasRange) {
                if ($from) {
                    $engagementQuery->whereDate('occurred_at', '>=', $from);
                }
                if ($to) {
                    $engagementQuery->whereDate('occurred_at', '<=', $to);
                }
            } else {
                $engagementQuery->where('occurred_at', '>=', now()->subDays(30));
            }

            return [
                'institution' => ['id' => $institution->id, 'name' => $institution->name],
                'metrics' => [
                    'users_total' => $userQuery->count(),
                    'posts_total' => $postQuery->count(),
                    'stories_total' => $storyQuery->count(),
                    'events_total' => $eventQuery->count(),
                    'donations_total' => (float) $donationQuery->sum('amount'),
                    'engagement_events_30d' => $engagementQuery->count(),
                ],
            ];
        });

        return response()->json($payload);
    }

    public function platform(Request $request)
    {
        if ($request->user()->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $from = $request->query('from');
        $to = $request->query('to');
        $hasRange = $request->filled('from') || $request->filled('to');
        $payload = $this->buildPlatformPayload($from, $to, $hasRange);

        return response()->json($payload);
    }

    public function exportPlatformSchoolsPdf(Request $request)
    {
        if ($request->user()->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $from = $request->query('from');
        $to = $request->query('to');
        $hasRange = $request->filled('from') || $request->filled('to');
        $status = $request->query('status');
        $location = $request->query('location');
        $payload = $this->buildPlatformPayload($from, $to, $hasRange);
        $schools = collect($payload['institution_summary']['schools'] ?? [])
            ->filter(function (array $row) use ($status, $location) {
                $statusOk = !$status || ($row['status'] ?? null) === $status;
                $locationOk = !$location || ($row['location'] ?? null) === $location;
                return $statusOk && $locationOk;
            })
            ->values();

        $html = view('reports.schools', [
            'title' => 'School Summary Report',
            'generatedAt' => now()->format('Y-m-d H:i'),
            'schools' => $schools,
            'summary' => [
                ['label' => 'Schools', 'value' => $payload['metrics']['institutions_total'] ?? 0],
                ['label' => 'Users across schools', 'value' => $payload['institution_summary']['users_across_schools'] ?? 0],
                ['label' => 'Active schools', 'value' => $payload['metrics']['active_schools_total'] ?? 0],
                ['label' => 'Suspended schools', 'value' => $payload['metrics']['suspended_schools_total'] ?? 0],
                ['label' => 'Avg users / school', 'value' => $payload['metrics']['avg_users_per_school'] ?? 0],
            ],
            'period' => $payload['institution_summary']['period'] ?? ['from' => null, 'to' => null],
        ])->render();

        $options = new Options();
        $options->set('isRemoteEnabled', true);
        $dompdf = new Dompdf($options);
        $dompdf->loadHtml($html);
        $dompdf->setPaper('a4', 'landscape');
        $dompdf->render();

        return response($dompdf->output(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="school-summary-report.pdf"',
        ]);
    }

    public function contentPerformance(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $query = Post::query()
            ->with('user:id,name,institution_id')
            ->withCount(['comments', 'reactions', 'reports']);
        if ($actor->role === 'institution_admin') {
            $query->where('institution_id', $actor->institution_id);
        } elseif ($request->filled('institution_id')) {
            $query->where('institution_id', (int) $request->query('institution_id'));
        }

        if ($request->filled('from')) {
            $query->whereDate('created_at', '>=', $request->query('from'));
        }
        if ($request->filled('to')) {
            $query->whereDate('created_at', '<=', $request->query('to'));
        }
        if ($request->filled('min_reactions')) {
            $query->having('reactions_count', '>=', (int) $request->query('min_reactions'));
        }

        $cacheKey = sprintf(
            'analytics:content:%s:%s:%s',
            $actor->role === 'institution_admin' ? (int) $actor->institution_id : ($request->query('institution_id') ?: 'all'),
            $request->query('from') ?: 'none',
            $request->query('to') ?: 'none'
        );

        $payload = Cache::remember($cacheKey, now()->addMinutes(5), function () use ($query) {
            $top = $query->orderByDesc('reactions_count')->orderByDesc('comments_count')->limit(20)->get();
            return [
                'data' => $top,
                'meta' => ['total' => $top->count()],
            ];
        });

        return response()->json($payload);
    }

    public function userOverview(Request $request)
    {
        $user = $request->user();
        $cacheKey = sprintf('analytics:user:%d', $user->id);

        $payload = Cache::remember($cacheKey, now()->addMinutes(5), function () use ($user) {
            $profileViews7d = AnalyticsEvent::where('event_type', 'profile_view')
                ->where('entity_type', 'user')
                ->where('entity_id', $user->id)
                ->where('occurred_at', '>=', now()->subDays(7))
                ->count();

            $postsTotal = Post::where('user_id', $user->id)->count();
            $eventsGoing = Event::whereHas('rsvps', function ($q) use ($user) {
                $q->where('user_id', $user->id)->where('status', 'going');
            })->count();

            return [
                'metrics' => [
                    'profile_views_7d' => $profileViews7d,
                    'posts_total' => $postsTotal,
                    'events_going' => $eventsGoing,
                ],
            ];
        });

        return response()->json($payload);
    }

    private function buildPlatformPayload(?string $from, ?string $to, bool $hasRange): array
    {
        $userQuery = User::query();
        $postQuery = Post::query();
        $eventQuery = Event::query();
        $institutionQuery = Institution::query();
        if ($from) {
            $userQuery->whereDate('created_at', '>=', $from);
            $postQuery->whereDate('created_at', '>=', $from);
            $eventQuery->whereDate('created_at', '>=', $from);
            $institutionQuery->whereDate('created_at', '>=', $from);
        }
        if ($to) {
            $userQuery->whereDate('created_at', '<=', $to);
            $postQuery->whereDate('created_at', '<=', $to);
            $eventQuery->whereDate('created_at', '<=', $to);
            $institutionQuery->whereDate('created_at', '<=', $to);
        }

        $periodStart = $from ?: now()->subDays(30)->toDateString();
        $periodEnd = $to ?: now()->toDateString();

        $institutionSnapshot = Institution::query()
            ->withCount([
                'yearGroups',
                'posts',
                'events',
            ])
            ->orderBy('name')
            ->get();

        $approvedMemberships = InstitutionMembership::query()
            ->where('status', 'approved')
            ->get(['institution_id', 'user_id', 'role', 'created_at']);

        $directUsers = User::query()
            ->whereNotNull('institution_id')
            ->get(['id', 'institution_id', 'role', 'created_at']);

        $membersByInstitution = [];
        $newMembersByInstitution = [];
        $adminsByInstitution = [];

        foreach ($directUsers as $user) {
            $institutionId = (int) $user->institution_id;
            if ($institutionId <= 0) {
                continue;
            }
            $membersByInstitution[$institutionId] ??= [];
            $membersByInstitution[$institutionId][$user->id] = true;

            if ($user->created_at && $user->created_at->toDateString() >= $periodStart && $user->created_at->toDateString() <= $periodEnd) {
                $newMembersByInstitution[$institutionId] ??= [];
                $newMembersByInstitution[$institutionId][$user->id] = true;
            }

            if ($user->role === 'institution_admin') {
                $adminsByInstitution[$institutionId] ??= [];
                $adminsByInstitution[$institutionId][$user->id] = true;
            }
        }

        foreach ($approvedMemberships as $membership) {
            $institutionId = (int) $membership->institution_id;
            if ($institutionId <= 0) {
                continue;
            }
            $membersByInstitution[$institutionId] ??= [];
            $membersByInstitution[$institutionId][$membership->user_id] = true;

            if ($membership->created_at && $membership->created_at->toDateString() >= $periodStart && $membership->created_at->toDateString() <= $periodEnd) {
                $newMembersByInstitution[$institutionId] ??= [];
                $newMembersByInstitution[$institutionId][$membership->user_id] = true;
            }

            if ($membership->role === 'institution_admin') {
                $adminsByInstitution[$institutionId] ??= [];
                $adminsByInstitution[$institutionId][$membership->user_id] = true;
            }
        }

        $donationsByInstitution = Donation::query()
            ->selectRaw('donation_campaigns.institution_id as institution_id, COALESCE(SUM(donations.amount), 0) as total')
            ->join('donation_campaigns', 'donation_campaigns.id', '=', 'donations.campaign_id')
            ->where('donations.status', 'success')
            ->groupBy('donation_campaigns.institution_id')
            ->pluck('total', 'institution_id');

        $attendanceByInstitution = EventRsvp::query()
            ->selectRaw('events.institution_id as institution_id, COUNT(event_rsvps.id) as total')
            ->join('events', 'events.id', '=', 'event_rsvps.event_id')
            ->where('event_rsvps.status', 'going')
            ->groupBy('events.institution_id')
            ->pluck('total', 'institution_id');

        $verificationByInstitution = Profile::query()
            ->selectRaw('users.institution_id as institution_id, COUNT(profiles.id) as total')
            ->join('users', 'users.id', '=', 'profiles.user_id')
            ->where('profiles.verification_status', 'pending')
            ->whereNotNull('users.institution_id')
            ->groupBy('users.institution_id')
            ->pluck('total', 'institution_id');

        $latestPosts = Post::query()
            ->selectRaw('institution_id, MAX(created_at) as latest_post_at')
            ->whereNotNull('institution_id')
            ->groupBy('institution_id')
            ->pluck('latest_post_at', 'institution_id');

        $latestEvents = Event::query()
            ->selectRaw('institution_id, MAX(created_at) as latest_event_at')
            ->whereNotNull('institution_id')
            ->groupBy('institution_id')
            ->pluck('latest_event_at', 'institution_id');

        $latestUsers = User::query()
            ->selectRaw('institution_id, MAX(created_at) as latest_user_at')
            ->whereNotNull('institution_id')
            ->groupBy('institution_id')
            ->pluck('latest_user_at', 'institution_id');

        $transactionQuery = PaymentTransaction::query();
        $revenueQuery = PaymentTransaction::where('status', 'success')->whereIn('type', ['event_ticket', 'membership_fee', 'subscription']);
        $donationQuery = PaymentTransaction::where('status', 'success')->where('type', 'donation');
        if ($from) {
            $transactionQuery->whereDate('created_at', '>=', $from);
            $revenueQuery->whereDate('created_at', '>=', $from);
            $donationQuery->whereDate('created_at', '>=', $from);
        }
        if ($to) {
            $transactionQuery->whereDate('created_at', '<=', $to);
            $revenueQuery->whereDate('created_at', '<=', $to);
            $donationQuery->whereDate('created_at', '<=', $to);
        }

        $growthQuery = User::query();
        $engagementQuery = AnalyticsEvent::query();
        if ($hasRange) {
            if ($from) {
                $growthQuery->whereDate('created_at', '>=', $from);
                $engagementQuery->whereDate('occurred_at', '>=', $from);
            }
            if ($to) {
                $growthQuery->whereDate('created_at', '<=', $to);
                $engagementQuery->whereDate('occurred_at', '<=', $to);
            }
        } else {
            $growthQuery->where('created_at', '>=', now()->subDays(30));
            $engagementQuery->where('occurred_at', '>=', now()->subDays(30));
        }

        $institutionsTotal = (int) $institutionQuery->count();
        $activeSchools = (int) $institutionSnapshot->where('status', 'active')->count();
        $suspendedSchools = (int) $institutionSnapshot->where('status', 'suspended')->count();
        $pendingSchools = (int) $institutionSnapshot->where('status', 'pending')->count();
        $institutionAdminsTotal = collect($adminsByInstitution)->sum(fn ($admins) => count($admins));
        $usersAcrossSchools = collect($membersByInstitution)->sum(fn ($members) => count($members));
        $avgUsersPerSchool = $institutionsTotal > 0
            ? round($usersAcrossSchools / $institutionsTotal, 1)
            : 0;

        $schoolRows = $institutionSnapshot->toBase()->map(function (Institution $institution) use (
            $donationsByInstitution,
            $attendanceByInstitution,
            $verificationByInstitution,
            $latestPosts,
            $latestEvents,
            $latestUsers,
            $membersByInstitution,
            $newMembersByInstitution,
            $adminsByInstitution
        ) {
            $latestActivity = collect([
                $latestPosts[$institution->id] ?? null,
                $latestEvents[$institution->id] ?? null,
                $latestUsers[$institution->id] ?? null,
            ])->filter()->map(fn ($value) => \Illuminate\Support\Carbon::parse($value))->sortDesc()->first();

            $inactiveDays = $latestActivity ? now()->diffInDays($latestActivity) : null;
            $inactiveBucket = 'active';
            if ($inactiveDays === null || $inactiveDays >= 90) {
                $inactiveBucket = 'inactive_90d';
            } elseif ($inactiveDays >= 60) {
                $inactiveBucket = 'inactive_60d';
            } elseif ($inactiveDays >= 30) {
                $inactiveBucket = 'inactive_30d';
            }

            return [
                'id' => $institution->id,
                'school_id' => $institution->school_id,
                'name' => $institution->name,
                'status' => $institution->status,
                'location' => $institution->location,
                'users_count' => count($membersByInstitution[$institution->id] ?? []),
                'new_users_count' => count($newMembersByInstitution[$institution->id] ?? []),
                'admins_count' => count($adminsByInstitution[$institution->id] ?? []),
                'year_groups_count' => (int) $institution->year_groups_count,
                'posts_count' => (int) $institution->posts_count,
                'events_count' => (int) $institution->events_count,
                'donations_total' => round((float) ($donationsByInstitution[$institution->id] ?? 0), 2),
                'event_attendance_total' => (int) ($attendanceByInstitution[$institution->id] ?? 0),
                'pending_verifications_count' => (int) ($verificationByInstitution[$institution->id] ?? 0),
                'inactive_days' => $inactiveDays,
                'inactive_bucket' => $inactiveBucket,
            ];
        })->sortByDesc('users_count')->values();

        $largestSchool = $schoolRows->first();

        $inactiveCounts = [
            'inactive_30d' => (int) $schoolRows->where('inactive_bucket', 'inactive_30d')->count(),
            'inactive_60d' => (int) $schoolRows->where('inactive_bucket', 'inactive_60d')->count(),
            'inactive_90d' => (int) $schoolRows->where('inactive_bucket', 'inactive_90d')->count(),
        ];
        $topGrowing = $schoolRows->sortByDesc('new_users_count')->take(5)->values();
        $needsAttention = $schoolRows->filter(function (array $row) {
            return $row['admins_count'] === 0
                || $row['pending_verifications_count'] > 0
                || in_array($row['inactive_bucket'], ['inactive_30d', 'inactive_60d', 'inactive_90d'], true);
        })->values();

        return [
            'metrics' => [
                'users_total' => $userQuery->count(),
                'institutions_total' => $institutionsTotal,
                'posts_total' => $postQuery->count(),
                'events_total' => $eventQuery->count(),
                'transactions_total' => $transactionQuery->count(),
                'revenue_total' => (float) $revenueQuery->sum('amount'),
                'donations_total' => (float) $donationQuery->sum('amount'),
                'growth_users_30d' => $growthQuery->count(),
                'engagement_events_30d' => $engagementQuery->count(),
                'institution_admins_total' => $institutionAdminsTotal,
                'active_schools_total' => $activeSchools,
                'suspended_schools_total' => $suspendedSchools,
                'pending_schools_total' => $pendingSchools,
                'avg_users_per_school' => $avgUsersPerSchool,
            ],
                'institution_summary' => [
                    'users_across_schools' => $usersAcrossSchools,
                'largest_school' => $largestSchool ? [
                    'id' => $largestSchool['id'],
                    'name' => $largestSchool['name'],
                    'school_id' => $largestSchool['school_id'],
                    'users_count' => (int) $largestSchool['users_count'],
                ] : null,
                    'period' => [
                        'from' => $periodStart,
                        'to' => $periodEnd,
                    ],
                'inactive_counts' => $inactiveCounts,
                'top_growing' => $topGrowing,
                'needs_attention' => $needsAttention,
                'schools' => $schoolRows,
            ],
        ];
    }
}
