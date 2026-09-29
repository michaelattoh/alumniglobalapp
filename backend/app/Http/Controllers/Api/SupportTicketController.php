<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\SupportTicketCreateRequest;
use App\Http\Requests\Api\SupportTicketUpdateRequest;
use App\Http\Resources\Api\SupportTicketResource;
use App\Models\AuditLog;
use App\Models\SupportTicket;
use App\Models\SupportTicketMessage;
use App\Models\SystemSetting;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SupportTicketController extends Controller
{
    public function index(Request $request)
    {
        $tickets = SupportTicket::query()
            ->where('user_id', $request->user()->id)
            ->with(['user', 'institution', 'messages.user'])
            ->latest('updated_at')
            ->paginate((int) $request->query('per_page', 20));

        return $this->paginatedResponse($tickets, SupportTicketResource::class);
    }

    public function store(SupportTicketCreateRequest $request, NotificationService $notificationService)
    {
        $user = $request->user();
        $data = $request->validated();

        $ticket = DB::transaction(function () use ($user, $data) {
            $ticket = SupportTicket::create([
                'user_id' => $user->id,
                'institution_id' => $user->institution_id,
                'subject' => $data['subject'],
                'message' => $data['message'],
                'category' => $data['category'] ?? null,
                'priority' => $data['priority'] ?? 'normal',
                'status' => 'pending',
            ]);
            $ticket->forceFill([
                'reference' => $this->makeReference((int) $ticket->id),
            ])->save();

            SupportTicketMessage::create([
                'support_ticket_id' => $ticket->id,
                'user_id' => $user->id,
                'message' => $data['message'],
            ]);

            return $ticket;
        });

        $this->notifyAdminsOfNewTicket($ticket, $user, $notificationService);

        return response()->json([
            'message' => 'Ticket created',
            'ticket' => new SupportTicketResource($ticket->load(['user', 'institution', 'messages.user'])),
        ], 201);
    }

    public function resolve(
        SupportTicketUpdateRequest $request,
        SupportTicket $ticket,
        NotificationService $notificationService
    )
    {
        $actor = $request->user();
        if (!$this->canManageTicket($actor, $ticket)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();
        $replyText = trim((string) ($data['admin_reply'] ?? ''));
        DB::transaction(function () use ($ticket, $data, $actor, $replyText) {
            $ticket->update([
                'status' => $data['status'],
                'admin_reply' => $replyText !== '' ? $replyText : $ticket->admin_reply,
                'resolved_by' => $actor->id,
                'resolved_at' => in_array($data['status'], ['resolved', 'dismissed'], true)
                    ? now()
                    : null,
            ]);

            if ($replyText !== '') {
                SupportTicketMessage::create([
                    'support_ticket_id' => $ticket->id,
                    'user_id' => $actor->id,
                    'message' => $replyText,
                ]);
            }
        });

        AuditLog::record($actor, 'support.ticket_resolved', SupportTicket::class, $ticket->id, [
            'status' => $data['status'],
        ], $request);

        if ($replyText !== '') {
            $notificationService->notify(
                (int) $ticket->user_id,
                'support_reply',
                'Support replied to your ticket',
                $actor->name . ' replied to ' . ($ticket->reference ?: ('ticket #' . $ticket->id)) . '.',
                [
                    'screen' => 'support',
                    'route' => '/support',
                    'ticket_id' => (string) $ticket->id,
                    'ticket_reference' => (string) ($ticket->reference ?? ''),
                    'status' => $data['status'],
                    'sender_id' => (string) $actor->id,
                    'sender_name' => $actor->name,
                ],
            );
        }

        return response()->json([
            'message' => 'Ticket updated',
            'ticket' => new SupportTicketResource($ticket->fresh()->load(['user', 'institution', 'messages.user'])),
        ]);
    }

    public function reply(
        Request $request,
        SupportTicket $ticket,
        NotificationService $notificationService
    ) {
        $actor = $request->user();
        $data = $request->validate([
            'message' => ['required', 'string', 'max:2000'],
        ]);

        if (!$this->canAccessTicket($actor, $ticket)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $message = trim((string) $data['message']);
        if ($message === '') {
            return response()->json(['message' => 'Message is required'], 422);
        }

        $isAdmin = $this->canManageTicket($actor, $ticket);

        DB::transaction(function () use ($ticket, $actor, $message, $isAdmin) {
            SupportTicketMessage::create([
                'support_ticket_id' => $ticket->id,
                'user_id' => $actor->id,
                'message' => $message,
            ]);

            $ticket->update([
                'status' => $isAdmin ? $ticket->status : 'pending',
                'admin_reply' => $isAdmin ? $message : $ticket->admin_reply,
                'resolved_by' => $isAdmin ? $actor->id : $ticket->resolved_by,
                'resolved_at' => $isAdmin ? $ticket->resolved_at : null,
            ]);
        });

        AuditLog::record($actor, 'support.ticket_replied', SupportTicket::class, $ticket->id, [
            'message' => $message,
            'sender_role' => $isAdmin ? 'admin' : 'user',
        ], $request);

        if ($isAdmin) {
            $notificationService->notify(
                (int) $ticket->user_id,
                'support_reply',
                'Support replied to your ticket',
                $actor->name . ' replied to ' . ($ticket->reference ?: ('ticket #' . $ticket->id)) . '.',
                [
                    'screen' => 'support',
                    'route' => '/support',
                    'ticket_id' => (string) $ticket->id,
                    'ticket_reference' => (string) ($ticket->reference ?? ''),
                    'sender_id' => (string) $actor->id,
                    'sender_name' => $actor->name,
                ],
            );
        } else {
            $this->notifyAdminsOfTicketReply($ticket, $actor, $notificationService);
        }

        return response()->json([
            'message' => 'Reply sent',
            'ticket' => new SupportTicketResource($ticket->fresh()->load(['user', 'institution', 'messages.user'])),
        ]);
    }

    private function notifyAdminsOfNewTicket(
        SupportTicket $ticket,
        $actor,
        NotificationService $notificationService
    ): void {
        $admins = $this->eligibleAdminsForTicket($ticket);

        foreach ($admins as $admin) {
            if ((int) $admin->id === (int) $actor->id) {
                continue;
            }

            $route = $this->isBillingTicket($ticket)
                ? '/accounting/billing'
                : ($admin->role === 'support_agent'
                ? '/customer-support/tickets'
                : ((int) $actor->institution_id > 0 && $admin->role !== 'super_admin'
                    ? '/institution/support'
                    : '/super/support'));

            $notificationService->notify(
                (int) $admin->id,
                'support_ticket',
                'New support ticket',
                $actor->name . ' submitted ' . ($ticket->reference ?: ('ticket #' . $ticket->id)) . '.',
                [
                    'screen' => 'support',
                    'route' => $route,
                    'ticket_id' => (string) $ticket->id,
                    'ticket_reference' => (string) ($ticket->reference ?? ''),
                    'user_id' => (string) $actor->id,
                    'institution_id' => $ticket->institution_id ? (string) $ticket->institution_id : null,
                    'priority' => (string) $ticket->priority,
                ],
            );
        }
    }

    private function notifyAdminsOfTicketReply(
        SupportTicket $ticket,
        User $actor,
        NotificationService $notificationService
    ): void {
        $admins = $this->eligibleAdminsForTicket($ticket);

        foreach ($admins as $admin) {
            if ((int) $admin->id === (int) $actor->id) {
                continue;
            }

            $route = $this->isBillingTicket($ticket)
                ? '/accounting/billing'
                : ($admin->role === 'support_agent'
                ? '/customer-support/tickets'
                : ((int) $actor->institution_id > 0 && $admin->role !== 'super_admin'
                    ? '/institution/support'
                    : '/super/support'));

            $notificationService->notify(
                (int) $admin->id,
                'support_ticket',
                'Support ticket updated',
                $actor->name . ' replied on ' . ($ticket->reference ?: ('ticket #' . $ticket->id)) . '.',
                [
                    'screen' => 'support',
                    'route' => $route,
                    'ticket_id' => (string) $ticket->id,
                    'ticket_reference' => (string) ($ticket->reference ?? ''),
                    'user_id' => (string) $actor->id,
                    'institution_id' => $ticket->institution_id ? (string) $ticket->institution_id : null,
                    'priority' => (string) $ticket->priority,
                ],
            );
        }
    }

    private function eligibleAdminsForTicket(SupportTicket $ticket)
    {
        $roles = $this->isBillingTicket($ticket)
            ? ['accountant']
            : ['super_admin', 'institution_admin', 'support_agent'];

        $adminQuery = User::query()->whereIn('role', $roles);

        return $adminQuery
            ->get()
            ->filter(function (User $admin) use ($ticket) {
                if ($this->isBillingTicket($ticket) && $this->isAccountingActor($admin)) {
                    return true;
                }

                if (in_array($admin->role, ['super_admin', 'support_agent'], true)) {
                    return true;
                }

                return $ticket->institution_id
                    && (int) $admin->institution_id === (int) $ticket->institution_id;
            })
            ->unique('id')
            ->values();
    }

    private function canAccessTicket(User $actor, SupportTicket $ticket): bool
    {
        if ((int) $ticket->user_id === (int) $actor->id) {
            return true;
        }

        if (!$this->canManageTicket($actor, $ticket)) {
            return false;
        }

        if ($this->isAccountingActor($actor)) {
            return $this->isBillingTicket($ticket);
        }

        if ($actor->role === 'super_admin' || $actor->role === 'support_agent') {
            return true;
        }

        return (int) $ticket->institution_id === (int) $actor->institution_id;
    }

    private function hasPermission(User $user, string $permission): bool
    {
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

    private function canManageTicket(User $actor, SupportTicket $ticket): bool
    {
        if ($this->isAccountingActor($actor)) {
            return $this->isBillingTicket($ticket);
        }

        if (!$this->hasPermission($actor, 'manage_support_queue')) {
            return false;
        }

        if ($actor->role === 'institution_admin') {
            return (int) $ticket->institution_id === (int) $actor->institution_id;
        }

        return true;
    }

    private function isBillingTicket(SupportTicket $ticket): bool
    {
        return strtolower((string) $ticket->category) === 'billing';
    }

    private function isAccountingActor(User $user): bool
    {
        if ($user->role === 'accountant') {
            return true;
        }

        $roleCatalog = SystemSetting::query()->where('key', 'role_catalog')->value('value');
        $portal = is_array($roleCatalog) && is_array($roleCatalog[$user->role] ?? null)
            ? ($roleCatalog[$user->role]['portal'] ?? null)
            : null;

        return $portal === 'accounting';
    }

    private function makeReference(int $ticketId): string
    {
        return 'AGN-SUP-' . str_pad((string) $ticketId, 6, '0', STR_PAD_LEFT);
    }
}
