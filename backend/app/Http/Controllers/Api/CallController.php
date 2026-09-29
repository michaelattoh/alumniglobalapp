<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\AgoraTokenService;
use Illuminate\Http\Request;

class CallController extends Controller
{
    public function token(Request $request, AgoraTokenService $agoraTokenService)
    {
        $user = $request->user();
        $data = $request->validate([
            'channel' => ['required', 'string', 'max:80'],
        ]);

        $appId = config('services.agora.app_id');
        if (!$appId) {
            return response()->json(['message' => 'Agora app id not configured'], 422);
        }

        $ttl = (int) env('AGORA_TOKEN_TTL_SECONDS', 3600);
        $ttl = max(300, min($ttl, 86400));
        $token = $agoraTokenService->buildRtcToken($data['channel'], (int) $user->id, $ttl);
        if (!$token) {
            return response()->json(['message' => 'Agora token generation unavailable'], 422);
        }

        return response()->json([
            'app_id' => $appId,
            'token' => $token,
            'channel' => $data['channel'],
            'uid' => (int) $user->id,
            'expires_in' => $ttl,
        ]);
    }
}
