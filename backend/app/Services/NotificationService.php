<?php

namespace App\Services;

use App\Models\NotificationPreference;
use App\Models\PushToken;
use App\Models\UserNotification;
use Illuminate\Support\Facades\Log;

class NotificationService
{
    public function __construct(
        private readonly FirebaseTopicMessagingService $firebase,
    ) {
    }

    public function notify(int $userId, string $type, string $title, ?string $body = null, array $data = []): ?UserNotification
    {
        $pref = NotificationPreference::firstOrCreate(
            ['user_id' => $userId],
            [
                'in_app_enabled' => true,
                'push_enabled' => true,
                'email_enabled' => false,
                'messages_enabled' => true,
                'connections_enabled' => true,
                'events_enabled' => true,
            ]
        );

        if (!$pref->in_app_enabled) {
            return null;
        }

        if ($type === 'message' && !$pref->messages_enabled) {
            return null;
        }

        if (str_starts_with($type, 'connection') && !$pref->connections_enabled) {
            return null;
        }

        if (str_starts_with($type, 'event') && !$pref->events_enabled) {
            return null;
        }

        $notification = UserNotification::create([
            'user_id' => $userId,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'data' => $data,
            'send_push' => $pref->push_enabled,
            'send_email' => $pref->email_enabled,
            'sent_at' => now(),
        ]);

        if ($notification->send_push) {
            $this->sendPush($userId, $notification);
        }

        return $notification;
    }

    public function notifyInAppOnly(int $userId, string $type, string $title, ?string $body = null, array $data = []): ?UserNotification
    {
        $pref = NotificationPreference::firstOrCreate(
            ['user_id' => $userId],
            [
                'in_app_enabled' => true,
                'push_enabled' => true,
                'email_enabled' => false,
                'messages_enabled' => true,
                'connections_enabled' => true,
                'events_enabled' => true,
            ]
        );

        if (!$pref->in_app_enabled) {
            return null;
        }

        if (str_starts_with($type, 'event') && !$pref->events_enabled) {
            return null;
        }

        return UserNotification::create([
            'user_id' => $userId,
            'type' => $type,
            'title' => $title,
            'body' => $body,
            'data' => $data,
            'send_push' => false,
            'send_email' => $pref->email_enabled,
            'sent_at' => now(),
        ]);
    }

    private function sendPush(int $userId, UserNotification $notification): void
    {
        $tokens = PushToken::query()
            ->where('user_id', $userId)
            ->pluck('token');

        if ($tokens->isEmpty()) {
            return;
        }

        $payload = array_merge($notification->data ?? [], [
            'notification_id' => (string) $notification->id,
            'type' => $notification->type,
        ]);

        foreach ($tokens as $token) {
            try {
                $this->firebase->sendToToken(
                    $token,
                    $notification->title,
                    $notification->body,
                    $payload,
                );
            } catch (\Throwable $e) {
                Log::warning('Failed to send push notification', [
                    'user_id' => $userId,
                    'notification_id' => $notification->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }
    }
}
