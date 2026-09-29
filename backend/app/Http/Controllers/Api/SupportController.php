<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\PostReportResource;
use App\Http\Resources\Api\UserReportResource;
use App\Http\Resources\Api\SupportTicketResource;
use App\Models\PostReport;
use App\Models\SystemSetting;
use App\Models\SupportTicket;
use App\Models\UserReport;
use Illuminate\Http\Request;
use Illuminate\Pagination\LengthAwarePaginator;

class SupportController extends Controller
{
    public function queue(Request $request)
    {
        $actor = $request->user();
        if (!$this->hasPermission($actor, 'manage_support_queue')) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $status = $request->query('status', 'pending');
        $category = strtolower((string) $request->query('category', ''));
        $perPage = (int) $request->query('per_page', 20);
        $page = (int) $request->query('page', 1);

        $userReportsQuery = UserReport::query()
            ->with(['reporter', 'reportedUser'])
            ->when($status, fn($q) => $q->where('status', $status));

        $postReportsQuery = PostReport::query()
            ->with(['reporter', 'post.media', 'post.user'])
            ->when($status, fn($q) => $q->where('status', $status));

        if ($actor->role === 'institution_admin') {
            $userReportsQuery->whereHas('reportedUser', function ($q) use ($actor) {
                $q->where('institution_id', $actor->institution_id);
            });
            $postReportsQuery->whereHas('post', function ($q) use ($actor) {
                $q->where('institution_id', $actor->institution_id);
            });
        }

        $userReports = $userReportsQuery->get()->map(function ($report) {
            return [
                'type' => 'user_report',
                'created_at' => $report->created_at,
                'payload' => (new UserReportResource($report))->resolve(),
            ];
        })->toBase();

        $postReports = $postReportsQuery->get()->map(function ($report) {
            return [
                'type' => 'post_report',
                'created_at' => $report->created_at,
                'payload' => (new PostReportResource($report))->resolve(),
            ];
        })->toBase();

        $ticketQuery = SupportTicket::query()
            ->with(['user', 'institution', 'messages.user'])
            ->when($status, fn($q) => $q->where('status', $status));

        if ($category !== '') {
            $ticketQuery->where('category', $category);
        }

        if ($actor->role === 'institution_admin') {
            $ticketQuery->where('institution_id', $actor->institution_id);
        }

        if ($this->isAccountingActor($actor)) {
            $userReports = collect();
            $postReports = collect();
            $ticketQuery->where('category', 'billing');
        } elseif ($actor->role === 'support_agent') {
            $ticketQuery->where(function ($q) {
                $q->whereNull('category')->orWhere('category', '!=', 'billing');
            });
        }

        $tickets = $ticketQuery->get()->map(function ($ticket) {
            return [
                'type' => 'support_ticket',
                'created_at' => $ticket->updated_at ?? $ticket->created_at,
                'payload' => (new SupportTicketResource($ticket))->resolve(),
            ];
        })->toBase();

        $combined = $userReports->merge($postReports)->merge($tickets)->sortByDesc('created_at')->values();
        $total = $combined->count();
        $items = $combined->slice(($page - 1) * $perPage, $perPage)->values();

        $paginator = new LengthAwarePaginator(
            $items,
            $total,
            $perPage,
            $page,
            ['path' => $request->url(), 'query' => $request->query()]
        );

        return response()->json([
            'data' => $paginator->items(),
            'meta' => $this->paginationMeta($paginator),
        ]);
    }

    private function hasPermission($user, string $permission): bool
    {
        if (!$user) {
            return false;
        }

        if ($user->role === 'super_admin') {
            return true;
        }

        if ($user->role === 'accountant' && $permission === 'manage_support_queue') {
            return true;
        }

        $roleCatalog = SystemSetting::query()->where('key', 'role_catalog')->value('value');
        if (is_array($roleCatalog) && is_array($roleCatalog[$user->role] ?? null)) {
            $roleConfig = $roleCatalog[$user->role];
            $permissions = is_array($roleConfig['permissions'] ?? null)
                ? $roleCatalog[$user->role]['permissions']
                : [];
            if (array_key_exists($permission, $permissions)) {
                return (bool) $permissions[$permission];
            }

            $portal = $roleConfig['portal'] ?? null;
            if ($portal === 'accounting' && $permission === 'manage_support_queue') {
                return true;
            }

            if ($portal === 'support' && $permission === 'manage_support_queue') {
                return true;
            }
        }

        if ($user->role === 'institution_admin') {
            $raw = SystemSetting::query()->where('key', 'admin_permissions')->value('value');
            $permissions = is_array($raw) ? $raw : [];
            return array_key_exists($permission, $permissions) ? (bool) $permissions[$permission] : false;
        }

        return false;
    }

    private function isAccountingActor($user): bool
    {
        if (!$user) {
            return false;
        }

        if ($user->role === 'accountant') {
            return true;
        }

        $roleCatalog = SystemSetting::query()->where('key', 'role_catalog')->value('value');
        $portal = is_array($roleCatalog) && is_array($roleCatalog[$user->role] ?? null)
            ? ($roleCatalog[$user->role]['portal'] ?? null)
            : null;

        return $portal === 'accounting';
    }
}
