<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\InstitutionJoinRequest;
use App\Http\Resources\Api\InstitutionMembershipResource;
use App\Models\Institution;
use App\Models\InstitutionMembership;
use Illuminate\Http\Request;

class InstitutionMembershipController extends Controller
{
    public function requestJoin(InstitutionJoinRequest $request, Institution $institution)
    {
        $user = $request->user();
        $data = $request->validated();

        $membership = InstitutionMembership::updateOrCreate(
            ['institution_id' => $institution->id, 'user_id' => $user->id],
            [
                'role' => 'member',
                'status' => 'pending',
                'graduation_year' => $data['graduation_year'] ?? null,
                'course' => $data['course'] ?? null,
                'department' => $data['department'] ?? null,
                'approved_by' => null,
                'approved_at' => null,
            ]
        );

        return response()->json([
            'message' => 'Join request submitted.',
            'membership' => new InstitutionMembershipResource($membership->load('user:id,name,email,institution_id')),
        ]);
    }

    public function listRequests(Request $request, Institution $institution)
    {
        if (!$this->canManageInstitution($request->user(), $institution->id)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $requests = InstitutionMembership::query()
            ->with(['user:id,name,email'])
            ->where('institution_id', $institution->id)
            ->where('status', 'pending')
            ->latest()
            ->paginate((int) $request->query('per_page', 20));

        return $this->paginatedResponse($requests, InstitutionMembershipResource::class);
    }

    public function approve(Request $request, Institution $institution, InstitutionMembership $membership)
    {
        $actor = $request->user();
        if (!$this->canManageInstitution($actor, $institution->id)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($membership->institution_id !== $institution->id) {
            return response()->json(['message' => 'Membership does not belong to this institution'], 422);
        }

        $membership->update([
            'status' => 'approved',
            'approved_by' => $actor->id,
            'approved_at' => now(),
        ]);

        $member = $membership->user;
        if (!$member->institution_id) {
            $member->update(['institution_id' => $institution->id]);
        }

        return response()->json(['message' => 'Join request approved']);
    }

    public function reject(Request $request, Institution $institution, InstitutionMembership $membership)
    {
        $actor = $request->user();
        if (!$this->canManageInstitution($actor, $institution->id)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($membership->institution_id !== $institution->id) {
            return response()->json(['message' => 'Membership does not belong to this institution'], 422);
        }

        $membership->update([
            'status' => 'rejected',
            'approved_by' => $actor->id,
            'approved_at' => now(),
        ]);

        return response()->json(['message' => 'Join request rejected']);
    }

    private function canManageInstitution($actor, int $institutionId): bool
    {
        if ($actor->role === 'super_admin') {
            return true;
        }

        if ($actor->role === 'institution_admin' || $actor->role === 'admin') {
            return (int) $actor->institution_id === $institutionId;
        }

        return false;
    }
}
