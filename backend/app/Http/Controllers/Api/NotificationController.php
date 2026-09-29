<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\UserNotificationResource;
use App\Models\UserNotification;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $notifications = UserNotification::query()
            ->where('user_id', $request->user()->id)
            ->latest()
            ->paginate((int) $request->query('per_page', 30));

        return $this->paginatedResponse($notifications, UserNotificationResource::class);
    }

    public function markRead(Request $request, UserNotification $notification)
    {
        if ((int) $notification->user_id !== (int) $request->user()->id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $notification->update([
            'is_read' => true,
            'read_at' => now(),
        ]);

        return response()->json(['message' => 'Notification marked as read']);
    }

    public function markAllRead(Request $request)
    {
        UserNotification::query()
            ->where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
            ]);

        return response()->json(['message' => 'All notifications marked as read']);
    }
}
