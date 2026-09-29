<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\GroupChatCreateRequest;
use App\Http\Requests\Api\GroupChatMessageRequest;
use App\Http\Requests\Api\GroupChatUpdateRequest;
use App\Http\Resources\Api\GroupChatMemberResource;
use App\Http\Resources\Api\GroupChatMessageResource;
use App\Http\Resources\Api\GroupChatResource;
use App\Models\GroupChat;
use App\Models\GroupChatMember;
use App\Models\GroupChatMessage;
use App\Models\GroupChatMessageReaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class GroupChatController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        $query = GroupChat::query()
            ->with('creator:id,name,email,institution_id')
            ->withCount('members')
            ->whereHas('members', function ($q) use ($user) {
                $q->where('user_id', $user->id);
            })
            ->latest();

        return $this->paginatedResponse($query->paginate((int) $request->query('per_page', 20)), GroupChatResource::class);
    }

    public function store(GroupChatCreateRequest $request)
    {
        $user = $request->user();
        $data = $request->validated();

        $chat = DB::transaction(function () use ($user, $data) {
            $chat = GroupChat::create([
                'created_by' => $user->id,
                'name' => $data['name'],
                'is_active' => true,
            ]);

            $memberIds = collect($data['member_ids'])
                ->map(fn ($id) => (int) $id)
                ->unique()
                ->reject(fn ($id) => $id === $user->id)
                ->values();

            GroupChatMember::create([
                'group_chat_id' => $chat->id,
                'user_id' => $user->id,
                'role' => 'admin',
                'joined_at' => now(),
            ]);

            foreach ($memberIds as $memberId) {
                GroupChatMember::create([
                    'group_chat_id' => $chat->id,
                    'user_id' => $memberId,
                    'role' => 'member',
                    'joined_at' => now(),
                ]);
            }

            return $chat;
        });

        return response()->json([
            'message' => 'Group chat created',
            'group' => new GroupChatResource($chat->load('creator:id,name,email,institution_id')->loadCount('members')),
        ], 201);
    }

    public function update(GroupChatUpdateRequest $request, GroupChat $groupChat)
    {
        $user = $request->user();

        $member = GroupChatMember::where('group_chat_id', $groupChat->id)
            ->where('user_id', $user->id)
            ->first();

        if (!$member || $member->role !== 'admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();
        $groupChat->update([
            'name' => $data['name'],
        ]);

        return response()->json([
            'message' => 'Group chat updated',
            'group' => new GroupChatResource($groupChat->fresh()->load('creator:id,name,email,institution_id')->loadCount('members')),
        ]);
    }

    public function messages(Request $request, GroupChat $groupChat)
    {
        $user = $request->user();

        $isMember = GroupChatMember::where('group_chat_id', $groupChat->id)
            ->where('user_id', $user->id)
            ->exists();

        if (!$isMember) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        GroupChatMember::where('group_chat_id', $groupChat->id)
            ->where('user_id', $user->id)
            ->update(['last_read_at' => now()]);

        $messages = GroupChatMessage::query()
            ->where('group_chat_id', $groupChat->id)
            ->with([
                'sender:id,name,email,institution_id',
                'replyTo.sender:id,name,email,institution_id',
                'reactions.user:id,name',
            ])
            ->latest()
            ->paginate((int) $request->query('per_page', 30));

        return $this->paginatedResponse($messages, GroupChatMessageResource::class);
    }

    public function members(Request $request, GroupChat $groupChat)
    {
        $user = $request->user();

        $isMember = GroupChatMember::where('group_chat_id', $groupChat->id)
            ->where('user_id', $user->id)
            ->exists();
        if (!$isMember) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $members = GroupChatMember::query()
            ->with('user:id,name,email,institution_id')
            ->where('group_chat_id', $groupChat->id)
            ->orderByRaw("role = 'admin' desc")
            ->orderBy('id')
            ->get();

        return response()->json([
            'data' => GroupChatMemberResource::collection($members),
        ]);
    }

    public function removeMember(Request $request, GroupChat $groupChat, int $userId)
    {
        $actor = $request->user();

        $actorMember = GroupChatMember::where('group_chat_id', $groupChat->id)
            ->where('user_id', $actor->id)
            ->first();
        if (!$actorMember) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->id !== $userId && $actorMember->role !== 'admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        GroupChatMember::where('group_chat_id', $groupChat->id)
            ->where('user_id', $userId)
            ->delete();

        return response()->json(['message' => 'Member removed']);
    }

    public function sendMessage(GroupChatMessageRequest $request, GroupChat $groupChat)
    {
        $user = $request->user();

        $isMember = GroupChatMember::where('group_chat_id', $groupChat->id)
            ->where('user_id', $user->id)
            ->exists();

        if (!$isMember) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();
        $replyToMessageId = $data['reply_to_message_id'] ?? null;

        if ($replyToMessageId) {
            $replyMessage = GroupChatMessage::query()
                ->where('id', $replyToMessageId)
                ->where('group_chat_id', $groupChat->id)
                ->exists();

            if (!$replyMessage) {
                return response()->json(['message' => 'Reply target not found'], 422);
            }
        }

        $message = GroupChatMessage::create([
            'group_chat_id' => $groupChat->id,
            'sender_id' => $user->id,
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

        return response()->json([
            'message' => 'Message sent',
            'data' => new GroupChatMessageResource($message->load([
                'sender:id,name,email,institution_id',
                'replyTo.sender:id,name,email,institution_id',
                'reactions.user:id,name',
            ])),
        ], 201);
    }

    public function reactToMessage(Request $request, GroupChatMessage $message)
    {
        $actor = $request->user();

        $isMember = GroupChatMember::where('group_chat_id', $message->group_chat_id)
            ->where('user_id', $actor->id)
            ->exists();
        if (!$isMember) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'emoji' => ['required', 'string', 'max:12'],
        ]);

        $reaction = GroupChatMessageReaction::updateOrCreate(
            [
                'group_chat_message_id' => $message->id,
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
}
