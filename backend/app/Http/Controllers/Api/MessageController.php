<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\MessageSendRequest;
use App\Http\Resources\Api\DirectMessageResource;
use App\Models\ConnectionRequest;
use App\Models\DirectMessage;
use App\Models\DirectMessageReaction;
use App\Models\User;
use App\Models\UserBlock;
use App\Services\NotificationService;
use Illuminate\Http\Request;

class MessageController extends Controller
{
    public function threads(Request $request)
    {
        $actor = $request->user();
        $limit = (int) $request->query('limit', 30);

        $recentMessages = DirectMessage::query()
            ->with(['sender:id,name', 'recipient:id,name'])
            ->where(function ($q) use ($actor) {
                $q->where('sender_id', $actor->id)
                    ->orWhere('recipient_id', $actor->id);
            })
            ->orderByDesc('created_at')
            ->limit(200)
            ->get();

        $unread = DirectMessage::query()
            ->selectRaw('sender_id, COUNT(*) as total')
            ->where('recipient_id', $actor->id)
            ->whereNull('read_at')
            ->groupBy('sender_id')
            ->pluck('total', 'sender_id');

        $threads = [];
        foreach ($recentMessages as $message) {
            $other = (int) ($message->sender_id === $actor->id ? $message->recipient_id : $message->sender_id);
            if (isset($threads[$other])) {
                continue;
            }
            $otherUser = $message->sender_id === $actor->id ? $message->recipient : $message->sender;
            $threads[$other] = [
                'user' => [
                    'id' => $otherUser?->id,
                    'name' => $otherUser?->name,
                ],
                'last_message' => $message->body ?? '',
                'last_message_at' => optional($message->created_at)?->toIso8601String(),
                'unread_count' => (int) ($unread[$other] ?? 0),
            ];
            if (count($threads) >= $limit) {
                break;
            }
        }

        return response()->json([
            'data' => array_values($threads),
        ]);
    }
    public function thread(Request $request, User $user)
    {
        $actor = $request->user();

        if ($this->isBlockedEitherWay($actor->id, $user->id)) {
            return response()->json(['message' => 'Messaging not allowed'], 403);
        }

        $messages = DirectMessage::query()
            ->with([
                'sender:id,name,email,institution_id',
                'recipient:id,name,email,institution_id',
                'replyTo.sender:id,name,email,institution_id',
                'reactions.user:id,name',
            ])
            ->where(function ($q) use ($actor, $user) {
                $q->where('sender_id', $actor->id)->where('recipient_id', $user->id);
            })
            ->orWhere(function ($q) use ($actor, $user) {
                $q->where('sender_id', $user->id)->where('recipient_id', $actor->id);
            })
            ->latest()
            ->paginate((int) $request->query('per_page', 30));

        DirectMessage::where('sender_id', $user->id)
            ->where('recipient_id', $actor->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return $this->paginatedResponse($messages, DirectMessageResource::class);
    }

    public function send(MessageSendRequest $request, User $user, NotificationService $notificationService)
    {
        $actor = $request->user();

        if ((int) $actor->id === (int) $user->id) {
            return response()->json(['message' => 'Cannot message yourself'], 422);
        }

        if ($this->isBlockedEitherWay($actor->id, $user->id)) {
            return response()->json(['message' => 'Messaging not allowed'], 403);
        }

        $connected = ConnectionRequest::query()
            ->where(function ($q) use ($actor, $user) {
                $q->where('from_user_id', $actor->id)->where('to_user_id', $user->id);
            })
            ->orWhere(function ($q) use ($actor, $user) {
                $q->where('from_user_id', $user->id)->where('to_user_id', $actor->id);
            })
            ->where('status', 'accepted')
            ->exists();

        $hasExistingThread = DirectMessage::query()
            ->where(function ($q) use ($actor, $user) {
                $q->where('sender_id', $actor->id)->where('recipient_id', $user->id);
            })
            ->orWhere(function ($q) use ($actor, $user) {
                $q->where('sender_id', $user->id)->where('recipient_id', $actor->id);
            })
            ->exists();

        if (!$connected && !$hasExistingThread) {
            return response()->json(['message' => 'You can only message accepted connections'], 403);
        }

        $data = $request->validated();
        $replyToMessageId = $data['reply_to_message_id'] ?? null;

        if ($replyToMessageId) {
            $replyMessage = DirectMessage::query()
                ->where('id', $replyToMessageId)
                ->where(function ($q) use ($actor, $user) {
                    $q->where(function ($sub) use ($actor, $user) {
                        $sub->where('sender_id', $actor->id)->where('recipient_id', $user->id);
                    })->orWhere(function ($sub) use ($actor, $user) {
                        $sub->where('sender_id', $user->id)->where('recipient_id', $actor->id);
                    });
                })
                ->exists();

            if (!$replyMessage) {
                return response()->json(['message' => 'Reply target not found'], 422);
            }
        }

        $message = DirectMessage::create([
            'sender_id' => $actor->id,
            'recipient_id' => $user->id,
            'reply_to_message_id' => $replyToMessageId,
            'body' => $data['body'] ?? '',
            'is_encrypted' => (bool) ($data['is_encrypted'] ?? !empty($data['encrypted_payload'])),
            'encrypted_payload' => $data['encrypted_payload'] ?? null,
            'encryption_version' => $data['encryption_version'] ?? null,
            'encrypted_nonce' => $data['encrypted_nonce'] ?? null,
            'sender_key_id' => $data['sender_key_id'] ?? null,
            'attachment_url' => $data['attachment_url'] ?? null,
            'attachment_type' => $data['attachment_type'] ?? null,
            'attachment_name' => $data['attachment_name'] ?? null,
            'attachment_size' => $data['attachment_size'] ?? null,
        ]);

        $preview = 'Attachment';
        if (!empty($data['encrypted_payload'])) {
            $preview = 'Encrypted message';
        } elseif (!empty($data['body'])) {
            $preview = $data['body'];
        }

        $notificationService->notify(
            $user->id,
            'message',
            'New message',
            $actor->name . ': ' . mb_substr($preview, 0, 80),
            ['sender_id' => $actor->id, 'message_id' => $message->id, 'attachment_url' => $data['attachment_url'] ?? null]
        );

        return response()->json([
            'message' => 'Message sent',
            'data' => new DirectMessageResource($message->load([
                'sender:id,name,email,institution_id',
                'recipient:id,name,email,institution_id',
                'replyTo.sender:id,name,email,institution_id',
                'reactions.user:id,name',
            ])),
        ], 201);
    }

    public function react(Request $request, DirectMessage $message)
    {
        $actor = $request->user();

        $isParticipant = ((int) $message->sender_id === (int) $actor->id)
            || ((int) $message->recipient_id === (int) $actor->id);
        if (!$isParticipant) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'emoji' => ['required', 'string', 'max:12'],
        ]);

        $reaction = DirectMessageReaction::updateOrCreate(
            [
                'direct_message_id' => $message->id,
                'user_id' => $actor->id,
            ],
            ['emoji' => $data['emoji']]
        );

        return response()->json([
            'message' => 'Reaction saved',
            'data' => [
                'id' => $reaction->id,
                'emoji' => $reaction->emoji,
                'user_id' => $reaction->user_id,
            ],
        ]);
    }

    private function isBlockedEitherWay(int $a, int $b): bool
    {
        return UserBlock::where('blocker_id', $a)->where('blocked_id', $b)->exists()
            || UserBlock::where('blocker_id', $b)->where('blocked_id', $a)->exists();
    }
}
