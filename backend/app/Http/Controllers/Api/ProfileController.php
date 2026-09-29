<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\ProfileUpdateRequest;
use App\Http\Resources\Api\ProfileResource;
use App\Http\Resources\Api\UserResource;
use App\Models\User;
use Illuminate\Http\Request;

class ProfileController extends Controller
{
    public function me(Request $request)
    {
        $user = $request->user()->load(['institution', 'profile']);

        return response()->json([
            'user' => new UserResource($user),
        ]);
    }

    public function updateMe(ProfileUpdateRequest $request)
    {
        $user = $request->user();
        $user->loadMissing('profile');

        if (!$user->profile) {
            $user->profile()->create([
                'visibility' => 'public',
                'verification_status' => 'unverified',
            ]);
            $user->refresh()->load('profile');
        }

        $data = $request->validated();

        // Optional: if alumni edits key identity fields, you can force verification back to pending
        // For MVP, leave verification status unchanged.

        $user->profile->update($data);

        return response()->json([
            'message' => 'Profile updated',
            'profile' => new ProfileResource($user->profile->fresh()),
        ]);
    }

    public function show(Request $request, User $user)
    {
        $viewer = $request->user();

        $user->load(['institution', 'profile']);

        if (!$user->profile) {
            return response()->json(['message' => 'Profile not found'], 404);
        }

        // Super admins can view all
        if ($this->isSuperAdmin($viewer)) {
            return response()->json(['user' => new UserResource($user)]);
        }

        // If profile is institution_only, allow only same institution OR institution admins of same institution
        if ($user->profile->visibility === 'institution_only') {
            $sameInstitution = $viewer->institution_id && $viewer->institution_id === $user->institution_id;
            if (!$sameInstitution) {
                return response()->json(['message' => 'Not authorized to view this profile'], 403);
            }
        }

        return response()->json(['user' => new UserResource($user)]);
    }

    public function updateUser(ProfileUpdateRequest $request, User $user)
    {
        $actor = $request->user();

        if (!$this->canManageProfile($actor, $user)) {
            return response()->json(['message' => 'Not authorized to update this profile'], 403);
        }

        $user->loadMissing('profile');

        if (!$user->profile) {
            $user->profile()->create([
                'visibility' => 'public',
                'verification_status' => 'unverified',
            ]);
            $user->refresh()->load('profile');
        }

        $data = $request->validated();
        $user->profile->update($data);

        return response()->json([
            'message' => 'Profile updated',
            'profile' => new ProfileResource($user->profile->fresh()),
            'user' => new UserResource($user->fresh()->load(['institution', 'profile'])),
        ]);
    }

    private function isSuperAdmin(User $user): bool
    {
        return $user->role === 'super_admin';
    }

    private function isInstitutionAdmin(User $user): bool
    {
        return $user->role === 'institution_admin';
    }

    private function canManageProfile(User $actor, User $target): bool
    {
        if ($this->isSuperAdmin($actor)) {
            return true;
        }

        if ($this->isInstitutionAdmin($actor)) {
            return $actor->institution_id && $actor->institution_id === $target->institution_id;
        }

        return false;
    }
}
