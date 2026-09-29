<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\ModerationResolveUserReportRequest;
use App\Http\Resources\Api\PostReportResource;
use App\Http\Resources\Api\UserReportResource;
use App\Models\AuditLog;
use App\Models\PostReport;
use App\Models\UserReport;
use Carbon\Carbon;
use Dompdf\Dompdf;
use Dompdf\Options;
use Illuminate\Http\Request;

class ModerationController extends Controller
{
    protected function applyUserReportFilters(Request $request, $actor, $query)
    {
        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }
        if ($request->filled('query')) {
            $search = $request->query('query');
            $query->where(function ($q) use ($search) {
                $q->where('reason', 'like', '%' . $search . '%')
                    ->orWhereHas('reporter', function ($qr) use ($search) {
                        $qr->where('name', 'like', '%' . $search . '%');
                    })
                    ->orWhereHas('reportedUser', function ($qr) use ($search) {
                        $qr->where('name', 'like', '%' . $search . '%');
                    });
            });
        }

        if ($request->filled('from')) {
            $query->whereDate('created_at', '>=', $request->query('from'));
        }
        if ($request->filled('to')) {
            $query->whereDate('created_at', '<=', $request->query('to'));
        }

        $institutionId = $request->query('institution_id');
        if ($actor->role === 'institution_admin') {
            $query->whereHas('reportedUser', function ($q) use ($actor) {
                $q->where('institution_id', $actor->institution_id);
            });
        } elseif ($institutionId) {
            $query->whereHas('reportedUser', function ($q) use ($institutionId) {
                $q->where('institution_id', $institutionId);
            });
        }

        return $query;
    }

    protected function applyPostReportFilters(Request $request, $actor, $query)
    {
        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }
        if ($request->filled('query')) {
            $search = $request->query('query');
            $query->where(function ($q) use ($search) {
                $q->where('reason', 'like', '%' . $search . '%')
                    ->orWhereHas('reporter', function ($qr) use ($search) {
                        $qr->where('name', 'like', '%' . $search . '%');
                    })
                    ->orWhereHas('post.user', function ($qr) use ($search) {
                        $qr->where('name', 'like', '%' . $search . '%');
                    });
            });
        }

        if ($request->filled('from')) {
            $query->whereDate('created_at', '>=', $request->query('from'));
        }
        if ($request->filled('to')) {
            $query->whereDate('created_at', '<=', $request->query('to'));
        }

        $institutionId = $request->query('institution_id');
        if ($actor->role === 'institution_admin') {
            $query->whereHas('post', function ($q) use ($actor) {
                $q->where('institution_id', $actor->institution_id);
            });
        } elseif ($institutionId) {
            $query->whereHas('post', function ($q) use ($institutionId) {
                $q->where('institution_id', $institutionId);
            });
        }

        return $query;
    }

    public function userReports(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $query = UserReport::query()->with(['reporter:id,name', 'reportedUser:id,name']);
        $query = $this->applyUserReportFilters($request, $actor, $query);

        return $this->paginatedResponse($query->latest()->paginate((int) $request->query('per_page', 30)), UserReportResource::class);
    }

    public function resolveUserReport(ModerationResolveUserReportRequest $request, UserReport $report)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $report->reportedUser->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();

        $report->update([
            'status' => $data['status'],
            'resolved_by' => $actor->id,
            'resolved_at' => now(),
        ]);

        AuditLog::record($actor, 'report.user_resolved', UserReport::class, $report->id, [
            'status' => $data['status'],
        ], $request);

        return response()->json([
            'message' => 'Report updated',
            'data' => new UserReportResource($report->fresh()->load(['reporter:id,name,email,institution_id', 'reportedUser:id,name,email,institution_id'])),
        ]);
    }

    public function postReports(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $query = PostReport::query()->with(['reporter:id,name', 'post.user:id,name,institution_id', 'post.media']);
        $query = $this->applyPostReportFilters($request, $actor, $query);

        return $this->paginatedResponse($query->latest()->paginate((int) $request->query('per_page', 30)), PostReportResource::class);
    }

    public function analytics(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $institutionId = $request->query('institution_id');
        if ($actor->role === 'institution_admin') {
            $institutionId = $actor->institution_id;
        }

        $from = $request->query('from');
        $to = $request->query('to');
        $start = $from ? Carbon::parse($from)->startOfDay() : now()->subDays(6)->startOfDay();
        $end = $to ? Carbon::parse($to)->endOfDay() : now()->endOfDay();

        $postBase = PostReport::query();
        $userBase = UserReport::query();

        if ($from) {
            $postBase->whereDate('created_at', '>=', $from);
            $userBase->whereDate('created_at', '>=', $from);
        }
        if ($to) {
            $postBase->whereDate('created_at', '<=', $to);
            $userBase->whereDate('created_at', '<=', $to);
        }

        if ($institutionId) {
            $postBase->whereHas('post', function ($q) use ($institutionId) {
                $q->where('institution_id', $institutionId);
            });
            $userBase->whereHas('reportedUser', function ($q) use ($institutionId) {
                $q->where('institution_id', $institutionId);
            });
        }

        $statusBuckets = ['pending', 'resolved', 'dismissed'];
        $postCounts = [];
        $userCounts = [];
        foreach ($statusBuckets as $status) {
            $postCounts[$status] = (clone $postBase)->where('status', $status)->count();
            $userCounts[$status] = (clone $userBase)->where('status', $status)->count();
        }

        $postReasons = (clone $postBase)
            ->selectRaw('reason, count(*) as total')
            ->groupBy('reason')
            ->orderByDesc('total')
            ->limit(5)
            ->get()
            ->map(fn ($row) => ['reason' => $row->reason ?: 'Other', 'count' => (int) $row->total]);

        $userReasons = (clone $userBase)
            ->selectRaw('reason, count(*) as total')
            ->groupBy('reason')
            ->orderByDesc('total')
            ->limit(5)
            ->get()
            ->map(fn ($row) => ['reason' => $row->reason ?: 'Other', 'count' => (int) $row->total]);

        $postTrend = (clone $postBase)
            ->selectRaw('date(created_at) as day, count(*) as total')
            ->groupBy('day')
            ->pluck('total', 'day')
            ->toArray();
        $userTrend = (clone $userBase)
            ->selectRaw('date(created_at) as day, count(*) as total')
            ->groupBy('day')
            ->pluck('total', 'day')
            ->toArray();

        $days = [];
        $cursor = $start->copy();
        while ($cursor->lte($end)) {
            $days[] = $cursor->toDateString();
            $cursor->addDay();
        }
        $trend = array_map(function ($day) use ($postTrend, $userTrend) {
            return [
                'day' => $day,
                'post_reports' => (int) ($postTrend[$day] ?? 0),
                'user_reports' => (int) ($userTrend[$day] ?? 0),
                'total' => (int) (($postTrend[$day] ?? 0) + ($userTrend[$day] ?? 0)),
            ];
        }, $days);

        $postAvg = (clone $postBase)
            ->whereNotNull('resolved_at')
            ->selectRaw('avg(timestampdiff(second, created_at, resolved_at)) as avg_seconds')
            ->value('avg_seconds');
        $userAvg = (clone $userBase)
            ->whereNotNull('resolved_at')
            ->selectRaw('avg(timestampdiff(second, created_at, resolved_at)) as avg_seconds')
            ->value('avg_seconds');

        $postSla = [
            'under_24h' => (clone $postBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) < 24')->count(),
            'under_48h' => (clone $postBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) between 24 and 47')->count(),
            'over_48h' => (clone $postBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) >= 48')->count(),
        ];
        $userSla = [
            'under_24h' => (clone $userBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) < 24')->count(),
            'under_48h' => (clone $userBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) between 24 and 47')->count(),
            'over_48h' => (clone $userBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) >= 48')->count(),
        ];

        $postInstitutionBreakdown = (clone $postBase)
            ->join('posts', 'posts.id', '=', 'post_reports.post_id')
            ->join('institutions', 'institutions.id', '=', 'posts.institution_id')
            ->selectRaw('institutions.id as institution_id, institutions.name as institution_name, count(*) as total')
            ->groupBy('institutions.id', 'institutions.name')
            ->orderByDesc('total')
            ->limit(5)
            ->get()
            ->map(fn ($row) => ['id' => (int) $row->institution_id, 'name' => $row->institution_name, 'count' => (int) $row->total]);

        $userInstitutionBreakdown = (clone $userBase)
            ->join('users', 'users.id', '=', 'user_reports.reported_user_id')
            ->join('institutions', 'institutions.id', '=', 'users.institution_id')
            ->selectRaw('institutions.id as institution_id, institutions.name as institution_name, count(*) as total')
            ->groupBy('institutions.id', 'institutions.name')
            ->orderByDesc('total')
            ->limit(5)
            ->get()
            ->map(fn ($row) => ['id' => (int) $row->institution_id, 'name' => $row->institution_name, 'count' => (int) $row->total]);

        return response()->json([
            'range' => [
                'from' => $start->toDateString(),
                'to' => $end->toDateString(),
            ],
            'counts' => [
                'posts' => $postCounts,
                'users' => $userCounts,
                'total' => array_sum($postCounts) + array_sum($userCounts),
            ],
            'reasons' => [
                'posts' => $postReasons,
                'users' => $userReasons,
            ],
            'trend' => $trend,
            'resolution_time_seconds' => [
                'posts' => $postAvg ? (float) $postAvg : 0,
                'users' => $userAvg ? (float) $userAvg : 0,
            ],
            'sla_buckets' => [
                'posts' => $postSla,
                'users' => $userSla,
            ],
            'institution_breakdown' => [
                'posts' => $postInstitutionBreakdown,
                'users' => $userInstitutionBreakdown,
            ],
        ]);
    }

    public function exportPdf(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $type = $request->query('type', 'posts');
        $perPage = (int) $request->query('limit', 200);
        $rows = collect();

        if ($type === 'users') {
            $query = UserReport::query()->with(['reporter:id,name', 'reportedUser:id,name']);
            $query = $this->applyUserReportFilters($request, $actor, $query);
            $rows = $query->latest()->limit($perPage)->get()->map(function ($row) {
                return [
                    'type' => 'User',
                    'reporter' => $row->reporter?->name ?? '-',
                    'subject' => $row->reportedUser?->name ?? '-',
                    'reason' => $row->reason ?? '-',
                    'status' => $row->status ?? '-',
                    'created_at' => optional($row->created_at)->format('Y-m-d H:i') ?? '-',
                ];
            });
        } elseif ($type === 'all') {
            $postQuery = PostReport::query()->with(['reporter:id,name', 'post.user:id,name']);
            $postQuery = $this->applyPostReportFilters($request, $actor, $postQuery);
            $userQuery = UserReport::query()->with(['reporter:id,name', 'reportedUser:id,name']);
            $userQuery = $this->applyUserReportFilters($request, $actor, $userQuery);
            $postRows = $postQuery->latest()->limit($perPage)->get()->map(function ($row) {
                return [
                    'type' => 'Post',
                    'reporter' => $row->reporter?->name ?? '-',
                    'subject' => $row->post?->user?->name ?? '-',
                    'reason' => $row->reason ?? '-',
                    'status' => $row->status ?? '-',
                    'created_at' => optional($row->created_at)->format('Y-m-d H:i') ?? '-',
                ];
            });
            $userRows = $userQuery->latest()->limit($perPage)->get()->map(function ($row) {
                return [
                    'type' => 'User',
                    'reporter' => $row->reporter?->name ?? '-',
                    'subject' => $row->reportedUser?->name ?? '-',
                    'reason' => $row->reason ?? '-',
                    'status' => $row->status ?? '-',
                    'created_at' => optional($row->created_at)->format('Y-m-d H:i') ?? '-',
                ];
            });
            $rows = $postRows->merge($userRows)->sortByDesc('created_at')->values()->take($perPage);
        } else {
            $query = PostReport::query()->with(['reporter:id,name', 'post.user:id,name']);
            $query = $this->applyPostReportFilters($request, $actor, $query);
            $rows = $query->latest()->limit($perPage)->get()->map(function ($row) {
                return [
                    'type' => 'Post',
                    'reporter' => $row->reporter?->name ?? '-',
                    'subject' => $row->post?->user?->name ?? '-',
                    'reason' => $row->reason ?? '-',
                    'status' => $row->status ?? '-',
                    'created_at' => optional($row->created_at)->format('Y-m-d H:i') ?? '-',
                ];
            });
        }

        // Summary stats for the same filter scope
        $postBase = PostReport::query();
        $userBase = UserReport::query();
        $postBase = $this->applyPostReportFilters($request, $actor, $postBase);
        $userBase = $this->applyUserReportFilters($request, $actor, $userBase);

        $statusBuckets = ['pending', 'resolved', 'dismissed'];
        $postCounts = [];
        $userCounts = [];
        foreach ($statusBuckets as $status) {
            $postCounts[$status] = (clone $postBase)->where('status', $status)->count();
            $userCounts[$status] = (clone $userBase)->where('status', $status)->count();
        }

        $postReasons = (clone $postBase)
            ->selectRaw('reason, count(*) as total')
            ->groupBy('reason')
            ->orderByDesc('total')
            ->limit(5)
            ->get()
            ->map(fn ($row) => ['reason' => $row->reason ?: 'Other', 'count' => (int) $row->total]);
        $userReasons = (clone $userBase)
            ->selectRaw('reason, count(*) as total')
            ->groupBy('reason')
            ->orderByDesc('total')
            ->limit(5)
            ->get()
            ->map(fn ($row) => ['reason' => $row->reason ?: 'Other', 'count' => (int) $row->total]);

        $postSla = [
            'under_24h' => (clone $postBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) < 24')->count(),
            'under_48h' => (clone $postBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) between 24 and 47')->count(),
            'over_48h' => (clone $postBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) >= 48')->count(),
        ];
        $userSla = [
            'under_24h' => (clone $userBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) < 24')->count(),
            'under_48h' => (clone $userBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) between 24 and 47')->count(),
            'over_48h' => (clone $userBase)->whereNotNull('resolved_at')->whereRaw('timestampdiff(hour, created_at, resolved_at) >= 48')->count(),
        ];

        $postAvg = (clone $postBase)
            ->whereNotNull('resolved_at')
            ->selectRaw('avg(timestampdiff(second, created_at, resolved_at)) as avg_seconds')
            ->value('avg_seconds');
        $userAvg = (clone $userBase)
            ->whereNotNull('resolved_at')
            ->selectRaw('avg(timestampdiff(second, created_at, resolved_at)) as avg_seconds')
            ->value('avg_seconds');

        $postInstitutionBreakdown = (clone $postBase)
            ->join('posts', 'posts.id', '=', 'post_reports.post_id')
            ->join('institutions', 'institutions.id', '=', 'posts.institution_id')
            ->selectRaw('institutions.name as institution_name, count(*) as total')
            ->groupBy('institutions.name')
            ->orderByDesc('total')
            ->limit(5)
            ->get()
            ->map(fn ($row) => ['name' => $row->institution_name, 'count' => (int) $row->total]);

        $userInstitutionBreakdown = (clone $userBase)
            ->join('users', 'users.id', '=', 'user_reports.reported_user_id')
            ->join('institutions', 'institutions.id', '=', 'users.institution_id')
            ->selectRaw('institutions.name as institution_name, count(*) as total')
            ->groupBy('institutions.name')
            ->orderByDesc('total')
            ->limit(5)
            ->get()
            ->map(fn ($row) => ['name' => $row->institution_name, 'count' => (int) $row->total]);

        $html = view('reports.table', [
            'title' => 'Reports Export',
            'generatedAt' => now()->format('Y-m-d H:i'),
            'rows' => $rows,
            'summary' => [
                'posts' => $postCounts,
                'users' => $userCounts,
                'reasons' => [
                    'posts' => $postReasons,
                    'users' => $userReasons,
                ],
                'sla' => [
                    'posts' => $postSla,
                    'users' => $userSla,
                ],
                'resolution_seconds' => [
                    'posts' => $postAvg ? (float) $postAvg : 0,
                    'users' => $userAvg ? (float) $userAvg : 0,
                ],
                'institutions' => [
                    'posts' => $postInstitutionBreakdown,
                    'users' => $userInstitutionBreakdown,
                ],
            ],
        ])->render();

        $options = new Options();
        $options->set('isRemoteEnabled', true);
        $options->set('isHtml5ParserEnabled', true);
        $dompdf = new Dompdf($options);
        $dompdf->loadHtml($html);
        $dompdf->setPaper('a4', 'landscape');
        $dompdf->render();

        return response($dompdf->output(), 200, [
            'Content-Type' => 'application/pdf',
            'Content-Disposition' => 'attachment; filename="reports.pdf"',
        ]);
    }

    public function resolvePostReport(ModerationResolveUserReportRequest $request, PostReport $report)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $report->post->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();

        $report->update([
            'status' => $data['status'],
            'resolved_by' => $actor->id,
            'resolved_at' => now(),
        ]);

        AuditLog::record($actor, 'report.post_resolved', PostReport::class, $report->id, [
            'status' => $data['status'],
        ], $request);

        return response()->json([
            'message' => 'Report updated',
            'data' => new PostReportResource($report->fresh()->load(['reporter:id,name,email,institution_id', 'post.user:id,name,email,institution_id'])),
        ]);
    }
}
