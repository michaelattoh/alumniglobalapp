<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class UserAdminController extends Controller
{
    public function suspend(Request $request, User $user)
    {
        $actor = $request->user();
        if (!$this->canManageUser($actor, $user)) {
            
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $user->update(['status' => 'suspended', 'suspended_at' => now()]);
        $user->tokens()->delete(); // revoke sessions

        return response()->json(['message' => 'User suspended']);
    }

    public function reactivate(Request $request, User $user)
    {
        $actor = $request->user();
        if (!$this->canManageUser($actor, $user)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $user->update(['status' => 'active', 'suspended_at' => null]);

        return response()->json(['message' => 'User reactivated']);
    }

    private function canManageUser(User $actor, User $target): bool
    {
        if ($actor->role === 'super_admin') return true;

        if ($actor->role === 'institution_admin') {
            return $actor->institution_id
                && $target->institution_id
                && $actor->institution_id === $target->institution_id;
        }

        return false;
    }
}
