<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Profile;
use App\Models\User;
use Illuminate\Http\Request;

class VerificationController extends Controller
{
    public function index(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['super_admin', 'institution_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $status = $request->query('status');
        $institutionId = $request->query('institution_id');

        $query = Profile::query()
            ->with(['user.institution:id,name'])
            ->when($status, fn($q) => $q->where('verification_status', $status))
            ->when($actor->role === 'institution_admin', function ($q) use ($actor) {
                $q->whereHas('user', function ($userQuery) use ($actor) {
                    $userQuery->where('institution_id', $actor->institution_id);
                });
            })
            ->when($actor->role === 'super_admin' && $institutionId, function ($q) use ($institutionId) {
                $q->whereHas('user', function ($userQuery) use ($institutionId) {
                    $userQuery->where('institution_id', (int) $institutionId);
                });
            })
            ->orderByDesc('updated_at');

        $perPage = (int) $request->query('per_page', 20);
        $page = $query->paginate($perPage);

        $data = collect($page->items())->map(function ($profile) {
            $user = $profile->user;
            return [
                'id' => $profile->id,
                'verification_status' => $profile->verification_status,
                'requested_at' => optional($profile->updated_at)?->toIso8601String(),
                'user' => $user ? [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'institution' => $user->institution ? [
                        'id' => $user->institution->id,
                        'name' => $user->institution->name,
                    ] : null,
                ] : null,
                'profile' => [
                    'headline' => $profile->headline,
                    'location' => $profile->location,
                    'graduation_year' => $profile->graduation_year,
                    'department' => $profile->department,
                    'program' => $profile->program,
                    'current_company' => $profile->current_company,
                    'current_role' => $profile->current_role,
                ],
            ];
        })->values();

        return response()->json([
            'data' => $data,
            'meta' => $this->paginationMeta($page),
        ]);
    }

    public function request(Request $request, User $user)
    {
        // Only the profile owner can request verification
        if ($request->user()->id !== $user->id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $user->loadMissing('profile');

        if (!$user->profile) {
            $user->profile()->create([
                'visibility' => 'public',
                'verification_status' => 'pending',
            ]);
        } else {
            if (in_array($user->profile->verification_status, ['verified'], true)) {
                return response()->json(['message' => 'Already verified'], 422);
            }
            $user->profile->update([
                'verification_status' => 'pending',
                'verified_by' => null,
                'verified_at' => null,
            ]);
        }

        return response()->json(['message' => 'Verification requested']);
    }

    public function verify(Request $request, User $user)
    {
        $actor = $request->user();

        if (!$this->canModerateProfile($actor, $user)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $user->loadMissing('profile');

        if (!$user->profile) {
            return response()->json(['message' => 'Profile not found'], 404);
        }

        $user->profile->update([
            'verification_status' => 'verified',
            'verified_by' => $actor->id,
            'verified_at' => now(),
        ]);

        return response()->json(['message' => 'Profile verified']);
    }

    public function reject(Request $request, User $user)
    {
        $actor = $request->user();

        if (!$this->canModerateProfile($actor, $user)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'reason' => ['nullable', 'string', 'max:300'],
        ]);

        $user->loadMissing('profile');

        if (!$user->profile) {
            return response()->json(['message' => 'Profile not found'], 404);
        }

        $user->profile->update([
            'verification_status' => 'rejected',
            'verified_by' => $actor->id,
            'verified_at' => now(),
            // If you later add a `verification_note` column, store $data['reason'] there.
        ]);

        return response()->json(['message' => 'Profile rejected']);
    }

    private function canModerateProfile(User $actor, User $target): bool
    {
        // Super admin can moderate all
        if ($actor->role === 'super_admin') {
            return true;
        }

        // Institution admin can moderate only within their institution
        if ($actor->role === 'institution_admin') {
            return $actor->institution_id !== null
                && $target->institution_id !== null
                && $actor->institution_id === $target->institution_id;
        }

        return false;
    }
}
