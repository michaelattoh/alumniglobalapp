<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\AnnouncementStoreRequest;
use App\Http\Resources\Api\AnnouncementResource;
use App\Models\Announcement;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;

class AnnouncementController extends Controller
{
    public function index(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $query = Announcement::query()
            ->with(['creator:id,name,email,institution_id', 'institution'])
            ->orderByDesc('created_at');

        if ($actor->role === 'institution_admin') {
            $query->where('audience', 'institution')->where('institution_id', $actor->institution_id);
        } elseif ($request->filled('institution_id')) {
            $query->where('institution_id', (int) $request->query('institution_id'));
        }

        if ($request->filled('audience')) {
            $query->where('audience', $request->query('audience'));
        }

        if ($request->filled('active')) {
            $query->where('is_active', $request->query('active') === 'true');
        }

        $page = $query->paginate((int) $request->query('per_page', 20));

        return $this->paginatedResponse($page, AnnouncementResource::class);
    }

    public function store(AnnouncementStoreRequest $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();

        if ($data['audience'] === 'global' && $actor->role !== 'super_admin') {
            return response()->json(['message' => 'Only super admins can publish global announcements'], 403);
        }

        $institutionId = $data['institution_id'] ?? $actor->institution_id;
        if ($data['audience'] === 'institution' && !$institutionId) {
            return response()->json(['message' => 'Institution announcement requires institution_id'], 422);
        }

        if ($actor->role === 'institution_admin' && $institutionId && (int) $actor->institution_id !== (int) $institutionId) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $announcement = Announcement::create([
            'created_by' => $actor->id,
            'institution_id' => $data['audience'] === 'global' ? null : $institutionId,
            'title' => $data['title'],
            'body' => $data['body'],
            'audience' => $data['audience'],
            'send_email' => (bool) ($data['send_email'] ?? false),
            'starts_at' => $data['starts_at'] ?? null,
            'ends_at' => $data['ends_at'] ?? null,
            'is_active' => $data['is_active'] ?? true,
        ]);

        $emailCount = 0;
        if (!empty($data['send_email'])) {
            $emailCount = $this->sendAnnouncementEmail($announcement);
            $announcement->update(['email_dispatched_at' => now()]);
        }

        return response()->json([
            'message' => 'Announcement created',
            'email_dispatched' => $emailCount,
            'announcement' => new AnnouncementResource($announcement->load(['creator:id,name,email,institution_id', 'institution'])),
        ], 201);
    }

    public function update(Request $request, Announcement $announcement)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $announcement->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'is_active' => ['nullable', 'boolean'],
            'title' => ['nullable', 'string', 'max:150'],
            'body' => ['nullable', 'string', 'max:5000'],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after:starts_at'],
        ]);

        $announcement->update($data);

        return response()->json([
            'message' => 'Announcement updated',
            'announcement' => new AnnouncementResource($announcement->fresh()->load(['creator:id,name,email,institution_id', 'institution'])),
        ]);
    }

    public function sendEmail(Request $request, Announcement $announcement)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $announcement->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $count = $this->sendAnnouncementEmail($announcement);
        $announcement->update([
            'send_email' => true,
            'email_dispatched_at' => now(),
        ]);

        return response()->json([
            'message' => 'Email dispatched',
            'email_dispatched' => $count,
        ]);
    }

    private function sendAnnouncementEmail(Announcement $announcement): int
    {
        $query = User::query()->whereNotNull('email');
        if ($announcement->audience === 'institution' && $announcement->institution_id) {
            $query->where('institution_id', $announcement->institution_id);
        }

        $fromName = null;
        $fromEmail = null;
        if ($announcement->institution_id) {
            $institution = $announcement->institution()->with('emailSetting')->first();
            if ($institution && $institution->emailSetting && $institution->emailSetting->is_enabled) {
                $fromName = $institution->emailSetting->sender_name;
                $fromEmail = $institution->emailSetting->sender_email;
            }
        }

        $count = 0;
        $query->chunkById(200, function ($users) use ($announcement, &$count, $fromName, $fromEmail) {
            foreach ($users as $user) {
                try {
                    Mail::raw($announcement->body, function ($message) use ($user, $announcement, $fromName, $fromEmail) {
                        if ($fromEmail) {
                            $message->from($fromEmail, $fromName ?: null);
                            $message->replyTo($fromEmail, $fromName ?: null);
                        }
                        $message->to($user->email)
                            ->subject($announcement->title);
                    });
                    $count++;
                } catch (\Throwable $e) {
                    // Ignore send failures in dev environments.
                }
            }
        });

        return $count;
    }
}
