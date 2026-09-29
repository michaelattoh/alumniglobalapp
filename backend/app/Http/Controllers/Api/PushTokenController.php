<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\PushTokenStoreRequest;
use App\Models\PushToken;
use Illuminate\Http\Request;

class PushTokenController extends Controller
{
    public function store(PushTokenStoreRequest $request)
    {
        $user = $request->user();
        $data = $request->validated();

        $token = PushToken::updateOrCreate(
            ['token' => $data['token']],
            [
                'user_id' => $user->id,
                'platform' => $data['platform'] ?? 'unknown',
                'device_id' => $data['device_id'] ?? null,
                'last_used_at' => now(),
            ]
        );

        return response()->json([
            'message' => 'Push token saved',
            'data' => ['id' => $token->id, 'token' => $token->token],
        ]);
    }

    public function destroy(Request $request)
    {
        $request->validate([
            'token' => ['required', 'string'],
        ]);

        PushToken::where('token', $request->input('token'))
            ->where('user_id', $request->user()->id)
            ->delete();

        return response()->json(['message' => 'Push token removed']);
    }
}
