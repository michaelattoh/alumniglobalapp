<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ScheduledNotificationBroadcast;
use App\Models\User;
use App\Services\FirebaseTopicMessagingService;
use App\Services\NotificationService;
use Illuminate\Support\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Throwable;

class AdminNotificationBroadcastController extends Controller
{
    public function __construct(
        private readonly FirebaseTopicMessagingService $firebase,
        private readonly NotificationService $notifications,
    ) {
    }

    public function store(Request $request): JsonResponse
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            abort(403, 'Only super admins can send broadcast notifications.');
        }

        $data = $request->validate([
            'topic' => ['required', 'string', 'in:general,alumni,school_admin,super_admin'],
            'title' => ['required', 'string', 'max:120'],
            'body' => ['nullable', 'string', 'max:500'],
            'data' => ['nullable', 'array'],
            'type' => ['nullable', 'string', 'max:60'],
            'create_in_app' => ['sometimes', 'boolean'],
            'scheduled_for' => ['nullable', 'date'],
        ]);

        $scheduledFor = !empty($data['scheduled_for']) ? Carbon::parse($data['scheduled_for']) : null;
        if ($scheduledFor && $scheduledFor->isFuture()) {
            $broadcast = ScheduledNotificationBroadcast::create([
                'created_by' => $actor->id,
                'topic' => $data['topic'],
                'title' => $data['title'],
                'body' => $data['body'] ?? null,
                'type' => $data['type'] ?? 'broadcast',
                'data' => $data['data'] ?? [],
                'create_in_app' => $data['create_in_app'] ?? true,
                'scheduled_for' => $scheduledFor,
            ]);

            return response()->json([
                'message' => 'Broadcast scheduled.',
                'scheduled' => true,
                'broadcast_id' => $broadcast->id,
                'scheduled_for' => $broadcast->scheduled_for?->toIso8601String(),
            ]);
        }

        try {
            $response = $this->firebase->sendToTopic(
                $data['topic'],
                $data['title'],
                $data['body'] ?? null,
                $data['data'] ?? [],
            );

            $inAppCount = 0;
            if ($data['create_in_app'] ?? true) {
                $query = User::query()->select(['id', 'role']);

                match ($data['topic']) {
                    'alumni' => $query->where('role', 'alumni'),
                    'school_admin' => $query->where('role', 'institution_admin'),
                    'super_admin' => $query->where('role', 'super_admin'),
                    default => null,
                };

                foreach ($query->cursor() as $user) {
                    $notification = $this->notifications->notifyInAppOnly(
                        $user->id,
                        $data['type'] ?? 'broadcast',
                        $data['title'],
                        $data['body'] ?? null,
                        array_merge($data['data'] ?? [], [
                            'topic' => $data['topic'],
                            'source' => 'firebase_broadcast',
                        ]),
                    );

                    if ($notification) {
                        $inAppCount++;
                    }
                }
            }

            return response()->json([
                'message' => 'Broadcast sent.',
                'firebase' => $response,
                'in_app_notifications_created' => $inAppCount,
            ]);
        } catch (Throwable $e) {
            report($e);

            return response()->json([
                'message' => $e->getMessage() ?: 'Unable to send broadcast notification.',
            ], 422);
        }
    }
}
