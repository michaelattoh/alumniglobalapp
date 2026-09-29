<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\InvitationCode;
use App\Models\StudentId;
use Illuminate\Http\Request;

class InvitationController extends Controller
{
    public function validateCode(Request $request)
    {
        $data = $request->validate([
            'code' => ['required','string'],
        ]);

        $invite = InvitationCode::with('institution')
            ->where('code', $data['code'])
            ->first();

        if ($invite) {
            if (!$invite->is_active) {
                return response()->json(['message' => 'Invalid code'], 422);
            }

            if ($invite->expires_at && now()->greaterThan($invite->expires_at)) {
                return response()->json(['message' => 'Code expired'], 422);
            }

            if ($invite->used_count >= $invite->max_uses) {
                return response()->json(['message' => 'Code has been used up'], 422);
            }

            return response()->json([
                'valid' => true,
                'role' => $invite->role,
                'institution' => [
                    'id' => $invite->institution->id,
                    'name' => $invite->institution->name,
                    'slug' => $invite->institution->slug,
                ],
            ]);
        }

        $studentId = StudentId::with('institution')
            ->where('code', $data['code'])
            ->where('status', 'issued')
            ->first();

        if (!$studentId) {
            return response()->json(['message' => 'Invalid code'], 422);
        }

        return response()->json([
            'valid' => true,
            'role' => 'alumni',
            'institution' => [
                'id' => $studentId->institution->id,
                'name' => $studentId->institution->name,
                'slug' => $studentId->institution->slug,
            ],
        ]);
    }
}
