<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GroupChatMember;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class TypingController extends Controller
{
    public function dmTyping(Request $request, User $user)
    {
        $actor = $request->user();
        if ((int) $actor->id === (int) $user->id) {
            return response()->json(['message' => 'Invalid target'], 422);
        }

        $key = $this->dmKey($actor->id, $user->id);
        Cache::put($key, now()->timestamp, now()->addSeconds(6));

        return response()->json(['message' => 'Typing updated']);
    }

    public function dmTypingStatus(Request $request, User $user)
    {
        $actor = $request->user();
        $key = $this->dmKey($user->id, $actor->id);
        $typing = Cache::has($key);

        return response()->json(['typing' => $typing]);
    }

    public function groupTyping(Request $request, int $groupChatId)
    {
        $actor = $request->user();
        $isMember = GroupChatMember::where('group_chat_id', $groupChatId)
            ->where('user_id', $actor->id)
            ->exists();
        if (!$isMember) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $key = $this->groupKey($groupChatId, $actor->id);
        Cache::put($key, now()->timestamp, now()->addSeconds(6));

        return response()->json(['message' => 'Typing updated']);
    }

    public function groupTypingStatus(Request $request, int $groupChatId)
    {
        $actor = $request->user();
        $isMember = GroupChatMember::where('group_chat_id', $groupChatId)
            ->where('user_id', $actor->id)
            ->exists();
        if (!$isMember) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $memberIds = GroupChatMember::where('group_chat_id', $groupChatId)
            ->where('user_id', '!=', $actor->id)
            ->pluck('user_id')
            ->all();

        $typingUsers = [];
        foreach ($memberIds as $memberId) {
            if (Cache::has($this->groupKey($groupChatId, $memberId))) {
                $typingUsers[] = $memberId;
            }
        }

        return response()->json(['typing_user_ids' => $typingUsers]);
    }

    private function dmKey(int $from, int $to): string
    {
        return "typing:dm:{$from}:{$to}";
    }

    private function groupKey(int $groupId, int $userId): string
    {
        return "typing:group:{$groupId}:{$userId}";
    }
}
