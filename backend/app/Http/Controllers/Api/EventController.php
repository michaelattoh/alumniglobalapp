<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\EventRsvpRequest;
use App\Http\Requests\Api\EventStoreRequest;
use App\Http\Requests\Api\EventUpdateRequest;
use App\Http\Resources\Api\EventResource;
use App\Http\Resources\Api\EventRsvpResource;
use App\Models\Event;
use App\Models\EventRsvp;
use App\Services\NotificationService;
use Illuminate\Http\Request;

class EventController extends Controller
{
    public function index(Request $request)
    {
        $viewer = $request->user();

        $query = Event::query()
            ->with('creator:id,name')
            ->with([
                'viewerRsvps' => fn ($q) => $q
                    ->where('user_id', $viewer->id)
                    ->latest('responded_at')
                    ->limit(1),
            ])
            ->withCount(['rsvps as going_count' => function ($q) {
                $q->where('status', 'going');
            }])
            ->where('is_active', true)
            ->where(function ($q) {
                $q->where(function ($active) {
                    $active->whereNotNull('ends_at')
                        ->where('ends_at', '>=', now());
                })->orWhere(function ($upcoming) {
                    $upcoming->whereNull('ends_at')
                        ->where('starts_at', '>=', now());
                });
            })
            ->orderBy('starts_at');

        if ($request->filled('institution_id')) {
            $query->where('institution_id', (int) $request->query('institution_id'));
        }

        if (in_array($viewer->role, ['institution_admin', 'admin'], true)) {
            $query->where(function ($q) use ($viewer) {
                $q->whereNull('institution_id');
                if ($viewer->institution_id) {
                    $q->orWhere('institution_id', $viewer->institution_id);
                }
            });
        }

        return $this->paginatedResponse($query->with('institution')->paginate((int) $request->query('per_page', 20)), EventResource::class);
    }

    public function store(EventStoreRequest $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();

        $institutionId = $data['institution_id'] ?? $actor->institution_id;
        if ($actor->role === 'institution_admin' && $institutionId && (int) $institutionId !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $event = Event::create([
            'created_by' => $actor->id,
            'institution_id' => $institutionId,
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'event_type' => $data['event_type'],
            'location' => $data['location'] ?? null,
            'meeting_url' => $data['meeting_url'] ?? null,
            'starts_at' => $data['starts_at'],
            'ends_at' => $data['ends_at'] ?? null,
            'capacity' => $data['capacity'] ?? null,
            'is_paid' => (bool) ($data['is_paid'] ?? false),
            'price' => $data['price'] ?? null,
            'currency' => $data['currency'] ?? null,
            'payment_provider' => $data['payment_provider'] ?? null,
            'payment_reference' => $data['payment_reference'] ?? null,
            'is_active' => true,
        ]);

        return response()->json([
            'message' => 'Event created',
            'event' => new EventResource($event->load(['creator:id,name,email,institution_id', 'institution'])->loadCount(['rsvps as going_count' => function ($q) {
                $q->where('status', 'going');
            }])),
        ], 201);
    }

    public function show(Request $request, Event $event)
    {
        $viewer = $request->user();
        if (
            $event->institution_id
            && in_array($viewer->role, ['institution_admin', 'admin'], true)
            && (int) $viewer->institution_id !== (int) $event->institution_id
        ) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        return response()->json([
            'event' => new EventResource($event->load([
                'creator:id,name,email,institution_id',
                'institution',
                'viewerRsvps' => fn ($q) => $q
                    ->where('user_id', $viewer->id)
                    ->latest('responded_at')
                    ->limit(1),
            ])->loadCount(['rsvps as going_count' => function ($q) {
                $q->where('status', 'going');
            }])),
        ]);
    }

    public function update(EventUpdateRequest $request, Event $event)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $event->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $data = $request->validated();
        if ($actor->role === 'institution_admin' && isset($data['institution_id']) && (int) $data['institution_id'] !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $event->update($data);

        return response()->json([
            'message' => 'Event updated',
            'event' => new EventResource($event->fresh()->load(['creator:id,name,email,institution_id', 'institution'])->loadCount(['rsvps as going_count' => function ($q) {
                $q->where('status', 'going');
            }])),
        ]);
    }

    public function destroy(Request $request, Event $event)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $event->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $event->update(['is_active' => false]);

        return response()->json(['message' => 'Event deactivated']);
    }

    public function forceDestroy(Request $request, Event $event)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $event->delete();

        return response()->json(['message' => 'Event deleted']);
    }

    public function rsvp(EventRsvpRequest $request, Event $event, NotificationService $notificationService)
    {
        $user = $request->user();
        $data = $request->validated();

        if (
            $event->institution_id
            && in_array($user->role, ['institution_admin', 'admin'], true)
            && (int) $event->institution_id !== (int) $user->institution_id
        ) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($data['status'] === 'going' && $event->capacity) {
            $goingCount = EventRsvp::where('event_id', $event->id)->where('status', 'going')->count();
            $existing = EventRsvp::where('event_id', $event->id)->where('user_id', $user->id)->first();
            $existingGoing = $existing && $existing->status === 'going';
            if (!$existingGoing && $goingCount >= $event->capacity) {
                return response()->json(['message' => 'Event capacity reached'], 422);
            }
        }

        $rsvp = EventRsvp::updateOrCreate(
            ['event_id' => $event->id, 'user_id' => $user->id],
            [
                'status' => $data['status'],
                'reminder_enabled' => (bool) ($data['reminder_enabled'] ?? true),
                'reminder_at' => $data['reminder_at'] ?? $event->starts_at?->copy()->subHour(),
                'reminder_sent_at' => null,
                'responded_at' => now(),
            ]
        );

        if ($event->created_by !== $user->id) {
            $notificationService->notify(
                $event->created_by,
                'event_rsvp',
                'New RSVP for ' . $event->title,
                $user->name . ' responded: ' . $rsvp->status,
                ['event_id' => $event->id, 'user_id' => $user->id]
            );
        }

        return response()->json([
            'message' => 'RSVP updated',
            'rsvp' => new EventRsvpResource($rsvp->load('user:id,name,email,institution_id')),
            'event' => new EventResource($event->fresh()->load([
                'creator:id,name,email,institution_id',
                'institution',
                'viewerRsvps' => fn ($q) => $q
                    ->where('user_id', $user->id)
                    ->latest('responded_at')
                    ->limit(1),
            ])->loadCount(['rsvps as going_count' => function ($q) {
                $q->where('status', 'going');
            }])),
        ]);
    }
}
