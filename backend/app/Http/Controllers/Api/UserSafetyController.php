<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\UserBlockRequest;
use App\Http\Requests\Api\UserReportCreateRequest;
use App\Http\Resources\Api\UserBlockResource;
use App\Http\Resources\Api\UserReportResource;
use App\Models\User;
use App\Models\UserBlock;
use App\Models\UserMute;
use App\Models\UserReport;
use Illuminate\Http\Request;

class UserSafetyController extends Controller
{
    public function block(UserBlockRequest $request, User $user)
    {
        $actor = $request->user();
        if ((int) $actor->id === (int) $user->id) {
            return response()->json(['message' => 'Cannot block yourself'], 422);
        }

        $data = $request->validated();

        $block = UserBlock::updateOrCreate(
            ['blocker_id' => $actor->id, 'blocked_id' => $user->id],
            ['reason' => $data['reason'] ?? null]
        );

        return response()->json(['message' => 'User blocked', 'data' => new UserBlockResource($block)]);
    }

    public function unblock(Request $request, User $user)
    {
        $actor = $request->user();

        UserBlock::where('blocker_id', $actor->id)
            ->where('blocked_id', $user->id)
            ->delete();

        return response()->json(['message' => 'User unblocked']);
    }

    public function report(UserReportCreateRequest $request, User $user)
    {
        $actor = $request->user();
        if ((int) $actor->id === (int) $user->id) {
            return response()->json(['message' => 'Cannot report yourself'], 422);
        }

        $data = $request->validated();

        $report = UserReport::updateOrCreate(
            ['reported_by' => $actor->id, 'reported_user_id' => $user->id],
            ['reason' => $data['reason'] ?? null, 'status' => 'pending', 'resolved_by' => null, 'resolved_at' => null]
        );

        return response()->json([
            'message' => 'User reported',
            'data' => new UserReportResource($report->load(['reporter:id,name,email,institution_id', 'reportedUser:id,name,email,institution_id'])),
        ]);
    }

    public function mute(Request $request, User $user)
    {
        $actor = $request->user();
        if ((int) $actor->id === (int) $user->id) {
            return response()->json(['message' => 'Cannot mute yourself'], 422);
        }

        UserMute::firstOrCreate([
            'user_id' => $actor->id,
            'muted_user_id' => $user->id,
        ]);

        return response()->json(['message' => 'User muted']);
    }

    public function unmute(Request $request, User $user)
    {
        $actor = $request->user();

        UserMute::where('user_id', $actor->id)
            ->where('muted_user_id', $user->id)
            ->delete();

        return response()->json(['message' => 'User unmuted']);
    }

    public function muted(Request $request)
    {
        $actor = $request->user();

        $rows = UserMute::query()
            ->with('mutedUser:id,name,email,institution_id')
            ->where('user_id', $actor->id)
            ->latest()
            ->get();

        return response()->json([
            'data' => $rows->map(function ($row) {
                return [
                    'id' => $row->id,
                    'muted_user' => new \App\Http\Resources\Api\UserLiteResource($row->mutedUser),
                    'created_at' => optional($row->created_at)?->toIso8601String(),
                ];
            }),
        ]);
    }
}
