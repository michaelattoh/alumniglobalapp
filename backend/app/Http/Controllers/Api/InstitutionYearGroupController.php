<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\InstitutionYearGroupJoinRequest;
use App\Http\Requests\Api\InstitutionYearGroupStoreRequest;
use App\Http\Resources\Api\InstitutionYearGroupMembershipResource;
use App\Http\Resources\Api\InstitutionYearGroupResource;
use App\Models\Institution;
use App\Models\InstitutionMembership;
use App\Models\InstitutionYearGroup;
use App\Models\InstitutionYearGroupMembership;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;

class InstitutionYearGroupController extends Controller
{
    public function index(Request $request, Institution $institution)
    {
        $actor = $request->user();
        if (!$this->canViewInstitutionCommunity($actor, $institution->id)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $groups = InstitutionYearGroup::query()
            ->where('institution_id', $institution->id)
            ->withCount([
                'memberships as approved_members_count' => fn ($query) => $query->where('status', 'approved'),
                'memberships as pending_members_count' => fn ($query) => $query->where('status', 'pending'),
            ])
            ->with([
                'memberships' => fn ($query) => $query
                    ->where('user_id', $actor->id)
                    ->latest(),
            ])
            ->orderByDesc('graduation_year')
            ->orderBy('name')
            ->get();

        return response()->json($this->collectionResponse($groups, InstitutionYearGroupResource::class));
    }

    public function store(InstitutionYearGroupStoreRequest $request, Institution $institution)
    {
        $actor = $request->user();
        if (!$this->canCreateYearGroup($actor, $institution->id)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();

        $group = InstitutionYearGroup::create([
            'institution_id' => $institution->id,
            'name' => trim($data['name']),
            'graduation_year' => $data['graduation_year'] ?? null,
            'description' => isset($data['description']) ? trim((string) $data['description']) : null,
            'created_by' => $actor->id,
        ]);

        $group->loadCount([
            'memberships as approved_members_count' => fn ($query) => $query->where('status', 'approved'),
            'memberships as pending_members_count' => fn ($query) => $query->where('status', 'pending'),
        ])->load([
            'memberships' => fn ($query) => $query->where('user_id', $actor->id),
        ]);

        return response()->json([
            'message' => 'Year group created.',
            'group' => new InstitutionYearGroupResource($group),
        ], 201);
    }

    public function requestJoin(InstitutionYearGroupJoinRequest $request, Institution $institution, InstitutionYearGroup $group, NotificationService $notifications)
    {
        $actor = $request->user();
        if (!$this->canViewInstitutionCommunity($actor, $institution->id)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($group->institution_id !== $institution->id) {
            return response()->json(['message' => 'Year group does not belong to this institution'], 422);
        }

        $profileGradYear = (int) optional($actor->profile)->graduation_year;
        if (
            $group->graduation_year
            && $profileGradYear
            && $actor->role === 'alumni'
            && $profileGradYear !== (int) $group->graduation_year
        ) {
            return response()->json([
                'message' => 'This year group is limited to alumni from that graduation year.',
            ], 422);
        }

        $membership = InstitutionYearGroupMembership::updateOrCreate(
            [
                'institution_year_group_id' => $group->id,
                'user_id' => $actor->id,
            ],
            [
                'status' => 'pending',
                'intro' => trim((string) ($request->validated()['intro'] ?? '')) ?: null,
                'approved_by' => null,
                'approved_at' => null,
            ],
        );

        $schoolAdminIds = User::query()
            ->whereIn('role', ['institution_admin', 'admin'])
            ->where('institution_id', $institution->id)
            ->pluck('id');

        foreach ($schoolAdminIds as $adminId) {
            $notifications->notify(
                (int) $adminId,
                'year_group.join_request',
                'New year-group join request',
                $actor->name . ' requested to join ' . $group->name . '.',
                [
                    'screen' => 'mentorship',
                    'institution_id' => (string) $institution->id,
                    'year_group_id' => (string) $group->id,
                    'year_group_membership_id' => (string) $membership->id,
                    'user_id' => (string) $actor->id,
                ],
            );
        }

        return response()->json([
            'message' => 'Year-group join request sent.',
            'membership' => new InstitutionYearGroupMembershipResource($membership->load('user:id,name,email,institution_id')),
        ], 201);
    }

    public function listRequests(Request $request, Institution $institution)
    {
        $actor = $request->user();
        if (!$this->canViewYearGroupRequests($actor, $institution->id)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $requests = InstitutionYearGroupMembership::query()
            ->with([
                'user:id,name,email,institution_id',
                'yearGroup:id,institution_id,name,graduation_year',
            ])
            ->whereHas('yearGroup', fn ($query) => $query->where('institution_id', $institution->id))
            ->where('status', 'pending')
            ->latest()
            ->paginate((int) $request->query('per_page', 20));

        return $this->paginatedResponse($requests, InstitutionYearGroupMembershipResource::class);
    }

    public function approve(Request $request, Institution $institution, InstitutionYearGroupMembership $membership, NotificationService $notifications)
    {
        $actor = $request->user();
        if (!$this->canApproveYearGroupRequests($actor, $institution->id)) {
            return response()->json(['message' => 'Only school admins can approve year-group joins.'], 403);
        }

        $membership->loadMissing('yearGroup', 'user.profile');
        $group = $membership->yearGroup;
        if (!$group || $group->institution_id !== $institution->id) {
            return response()->json(['message' => 'Request does not belong to this institution'], 422);
        }

        $membership->update([
            'status' => 'approved',
            'approved_by' => $actor->id,
            'approved_at' => now(),
        ]);

        $member = $membership->user;
        $notifications->notify(
            (int) $member->id,
            'year_group.approved',
            'Year-group request approved',
            'You are now part of ' . $group->name . '.',
            [
                'screen' => 'mentorship',
                'institution_id' => (string) $institution->id,
                'year_group_id' => (string) $group->id,
                'year_group_membership_id' => (string) $membership->id,
            ],
        );

        $peerIds = InstitutionYearGroupMembership::query()
            ->where('institution_year_group_id', $group->id)
            ->where('status', 'approved')
            ->where('user_id', '!=', $member->id)
            ->pluck('user_id');

        foreach ($peerIds as $peerId) {
            $notifications->notify(
                (int) $peerId,
                'year_group.member_joined',
                'Someone from your year group joined',
                $member->name . ' just joined ' . $group->name . '.',
                [
                    'screen' => 'mentorship',
                    'institution_id' => (string) $institution->id,
                    'year_group_id' => (string) $group->id,
                    'user_id' => (string) $member->id,
                ],
            );
        }

        return response()->json(['message' => 'Year-group request approved']);
    }

    public function reject(Request $request, Institution $institution, InstitutionYearGroupMembership $membership, NotificationService $notifications)
    {
        $actor = $request->user();
        if (!$this->canApproveYearGroupRequests($actor, $institution->id)) {
            return response()->json(['message' => 'Only school admins can approve year-group joins.'], 403);
        }

        $membership->loadMissing('yearGroup', 'user');
        $group = $membership->yearGroup;
        if (!$group || $group->institution_id !== $institution->id) {
            return response()->json(['message' => 'Request does not belong to this institution'], 422);
        }

        $membership->update([
            'status' => 'rejected',
            'approved_by' => $actor->id,
            'approved_at' => now(),
        ]);

        $notifications->notify(
            (int) $membership->user_id,
            'year_group.rejected',
            'Year-group request update',
            'Your request to join ' . $group->name . ' was declined.',
            [
                'screen' => 'mentorship',
                'institution_id' => (string) $institution->id,
                'year_group_id' => (string) $group->id,
                'year_group_membership_id' => (string) $membership->id,
            ],
        );

        return response()->json(['message' => 'Year-group request rejected']);
    }

    public function addMember(Request $request, Institution $institution, InstitutionYearGroup $group, NotificationService $notifications)
    {
        $actor = $request->user();
        if (!$this->canApproveYearGroupRequests($actor, $institution->id)) {
            return response()->json(['message' => 'Only school admins can add alumni to year groups.'], 403);
        }

        if ($group->institution_id !== $institution->id) {
            return response()->json(['message' => 'Year group does not belong to this institution'], 422);
        }

        $data = $request->validate([
            'user_id' => ['required', 'integer', 'exists:users,id'],
        ]);

        $member = User::query()
            ->with('profile')
            ->where('id', (int) $data['user_id'])
            ->where('role', 'alumni')
            ->where(function ($query) use ($institution) {
                $query->where('institution_id', $institution->id)
                    ->orWhereExists(function ($membershipQuery) use ($institution) {
                        $membershipQuery
                            ->selectRaw('1')
                            ->from('institution_memberships')
                            ->whereColumn('institution_memberships.user_id', 'users.id')
                            ->where('institution_memberships.institution_id', $institution->id)
                            ->where('institution_memberships.status', 'approved');
                    });
            })
            ->first();

        if (!$member) {
            return response()->json(['message' => 'Selected alumni was not found in this institution.'], 422);
        }

        $membership = InstitutionYearGroupMembership::updateOrCreate(
            [
                'institution_year_group_id' => $group->id,
                'user_id' => $member->id,
            ],
            [
                'status' => 'approved',
                'intro' => null,
                'approved_by' => $actor->id,
                'approved_at' => now(),
            ],
        );

        $notifications->notify(
            (int) $member->id,
            'year_group.assigned',
            'Added to a year group',
            'You were added to ' . $group->name . ' by your school admin.',
            [
                'screen' => 'mentorship',
                'institution_id' => (string) $institution->id,
                'year_group_id' => (string) $group->id,
                'year_group_membership_id' => (string) $membership->id,
            ],
        );

        return response()->json([
            'message' => 'Alumni added to year group.',
            'membership' => new InstitutionYearGroupMembershipResource(
                $membership->load('user:id,name,email,institution_id', 'yearGroup:id,institution_id,name,graduation_year')
            ),
        ]);
    }

    private function canViewInstitutionCommunity($actor, int $institutionId): bool
    {
        if ($actor->role === 'super_admin') {
            return true;
        }

        if (in_array($actor->role, ['institution_admin', 'admin'], true)) {
            return (int) $actor->institution_id === $institutionId;
        }

        if ((int) $actor->institution_id === $institutionId) {
            return true;
        }

        return InstitutionMembership::query()
            ->where('institution_id', $institutionId)
            ->where('user_id', $actor->id)
            ->where('status', 'approved')
            ->exists();
    }

    private function canCreateYearGroup($actor, int $institutionId): bool
    {
        if ($actor->role === 'super_admin') {
            return true;
        }

        return in_array($actor->role, ['institution_admin', 'admin'], true)
            && (int) $actor->institution_id === $institutionId;
    }

    private function canViewYearGroupRequests($actor, int $institutionId): bool
    {
        if ($actor->role === 'super_admin') {
            return true;
        }

        return in_array($actor->role, ['institution_admin', 'admin'], true)
            && (int) $actor->institution_id === $institutionId;
    }

    private function canApproveYearGroupRequests($actor, int $institutionId): bool
    {
        return in_array($actor->role, ['institution_admin', 'admin'], true)
            && (int) $actor->institution_id === $institutionId;
    }
}
