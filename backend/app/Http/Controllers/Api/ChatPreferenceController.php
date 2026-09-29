<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ChatPreference;
use Illuminate\Http\Request;

class ChatPreferenceController extends Controller
{
    public function show(Request $request, string $chatKey)
    {
        $preference = ChatPreference::firstOrCreate(
            [
                'user_id' => $request->user()->id,
                'chat_key' => $chatKey,
            ],
            ['wallpaper' => 'default']
        );

        return response()->json([
            'data' => [
                'chat_key' => $preference->chat_key,
                'wallpaper' => $preference->wallpaper ?? 'default',
            ],
        ]);
    }

    public function update(Request $request, string $chatKey)
    {
        $data = $request->validate([
            'wallpaper' => ['required', 'string', 'max:40'],
        ]);

        $preference = ChatPreference::updateOrCreate(
            [
                'user_id' => $request->user()->id,
                'chat_key' => $chatKey,
            ],
            ['wallpaper' => $data['wallpaper']]
        );

        return response()->json([
            'message' => 'Chat preference updated',
            'data' => [
                'chat_key' => $preference->chat_key,
                'wallpaper' => $preference->wallpaper,
            ],
        ]);
    }
}
