<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\NotificationPreferenceUpdateRequest;
use App\Http\Resources\Api\NotificationPreferenceResource;
use App\Models\NotificationPreference;
use Illuminate\Http\Request;

class NotificationPreferenceController extends Controller
{
    public function show(Request $request)
    {
        $preferences = NotificationPreference::firstOrCreate(
            ['user_id' => $request->user()->id],
            [
                'in_app_enabled' => true,
                'push_enabled' => true,
                'email_enabled' => false,
                'messages_enabled' => true,
                'connections_enabled' => true,
                'events_enabled' => true,
                'ai_personalization_enabled' => true,
            ]
        );

        return response()->json(['data' => new NotificationPreferenceResource($preferences)]);
    }

    public function update(NotificationPreferenceUpdateRequest $request)
    {
        $data = $request->validated();

        $preferences = NotificationPreference::firstOrCreate(
            ['user_id' => $request->user()->id],
            [
                'in_app_enabled' => true,
                'push_enabled' => true,
                'email_enabled' => false,
                'messages_enabled' => true,
                'connections_enabled' => true,
                'events_enabled' => true,
                'ai_personalization_enabled' => true,
            ]
        );

        $preferences->update($data);

        return response()->json([
            'message' => 'Notification preferences updated',
            'data' => new NotificationPreferenceResource($preferences->fresh()),
        ]);
    }
}
