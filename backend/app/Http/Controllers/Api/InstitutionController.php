<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\PostResource;
use App\Http\Resources\Api\InstitutionResource;
use App\Http\Requests\Api\InstitutionRegisterRequest;
use App\Http\Requests\Api\InstitutionProfileUpdateRequest;
use App\Models\Institution;
use App\Models\InstitutionMembership;
use App\Models\Post;
use App\Models\Story;
use App\Models\InvitationCode;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class InstitutionController extends Controller
{
    public function publicIndex(Request $request)
    {
        $search = trim((string) $request->query('search', ''));

        $query = Institution::query()
            ->select(['id', 'name', 'slug'])
            ->where('status', 'active')
            ->orderBy('name');

        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('slug', 'like', "%{$search}%");
            });
        }

        $institutions = $query->limit(25)->get();

        return response()->json([
            'data' => $institutions,
        ]);
    }

    public function publicShow(Institution $institution)
    {
        if ($institution->status !== 'active') {
            return response()->json(['message' => 'Institution not available'], 404);
        }

        return response()->json([
            'institution' => new InstitutionResource($institution),
        ]);
    }

    public function index(Request $request)
    {
        $search = trim((string) $request->query('search', ''));

        $query = Institution::query()
            ->select(['id', 'name', 'slug', 'status'])
            ->where('status', 'active')
            ->orderBy('name');

        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('slug', 'like', "%{$search}%");
            });
        }

        $institutions = $query->limit(25)->get();

        return response()->json([
            'data' => $institutions,
        ]);
    }

    public function feed(Request $request, Institution $institution)
    {
        $viewer = $request->user();
        $isMember = $viewer->institution_id === $institution->id
            || InstitutionMembership::query()
                ->where('institution_id', $institution->id)
                ->where('user_id', $viewer->id)
                ->where('status', 'approved')
                ->exists()
            || $viewer->role === 'super_admin';

        if (!$isMember) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $posts = Post::query()
            ->where('institution_id', $institution->id)
            ->with(['user:id,name', 'user.profile:id,user_id,avatar_url', 'media'])
            ->withCount(['comments', 'reactions'])
            ->where(function ($q) {
                $q->whereNull('scheduled_at')
                  ->orWhere('scheduled_at', '<=', now());
            })
            ->orderByDesc('is_pinned')
            ->latest()
            ->paginate((int) $request->query('per_page', 20));

        return $this->paginatedResponse($posts, PostResource::class);
    }

    public function analytics(Request $request, Institution $institution)
    {
        $actor = $request->user();
        $canView = $actor->role === 'super_admin'
            || (($actor->role === 'institution_admin' || $actor->role === 'admin') && (int) $actor->institution_id === (int) $institution->id);

        if (!$canView) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        return response()->json([
            'institution' => [
                'id' => $institution->id,
                'name' => $institution->name,
            ],
            'stats' => [
                'members_total' => InstitutionMembership::where('institution_id', $institution->id)->where('status', 'approved')->count(),
                'pending_join_requests' => InstitutionMembership::where('institution_id', $institution->id)->where('status', 'pending')->count(),
                'posts_total' => Post::where('institution_id', $institution->id)->count(),
                'stories_active' => Story::where('institution_id', $institution->id)->where('expires_at', '>', now())->count(),
            ],
        ]);
    }

    public function registerSchool(InstitutionRegisterRequest $request, NotificationService $notifications)
    {
        $actor = $request->user();
        if ($actor->role !== 'institution_admin' && $actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();

        $institution = Institution::create([
            'name' => $data['school_name'],
            'school_id' => $this->generateSchoolId(),
            'slug' => Str::slug($data['school_name']),
            'status' => 'pending',
        ]);

        $actor->institution_id = $institution->id;
        $actor->save();

        $code = 'SCH-' . Str::upper(Str::random(6));
        InvitationCode::create([
            'code' => $code,
            'institution_id' => $institution->id,
            'role' => 'institution_admin',
            'max_uses' => 1,
            'used_count' => 0,
            'is_active' => true,
            'expires_at' => now()->addYear(),
        ]);

        $this->notifySuperAdminsOfInstitutionRegistration($actor, $institution, $notifications);

        return response()->json([
            'message' => 'School registered. Verification pending.',
            'institution' => [
                'id' => $institution->id,
                'school_id' => $institution->school_id,
                'name' => $institution->name,
                'status' => $institution->status,
            ],
            'invitation_code' => $code,
        ], 201);
    }

    private function notifySuperAdminsOfInstitutionRegistration(User $actor, Institution $institution, NotificationService $notifications): void
    {
        $superAdminIds = User::query()
            ->where('role', 'super_admin')
            ->pluck('id');

        if ($superAdminIds->isEmpty()) {
            return;
        }

        foreach ($superAdminIds as $superAdminId) {
            $notifications->notify(
                (int) $superAdminId,
                'account.school_profile_submitted',
                'School profile submitted',
                "{$actor->name} submitted {$institution->name} for review.",
                [
                    'screen' => 'institutions',
                    'route' => '/super/institutions',
                    'institution_id' => (string) $institution->id,
                    'user_id' => (string) $actor->id,
                    'role' => $actor->role,
                ],
            );
        }
    }

    private function generateSchoolId(): string
    {
        do {
            $code = 'SCH-' . Str::upper(Str::random(6));
        } while (Institution::where('school_id', $code)->exists());

        return $code;
    }

    public function me(Request $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if (!$actor->institution_id) {
            return response()->json(['message' => 'Institution not assigned'], 422);
        }

        $institution = Institution::find($actor->institution_id);

        return response()->json([
            'institution' => $institution,
        ]);
    }

    public function updateMe(InstitutionProfileUpdateRequest $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'institution_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if (!$actor->institution_id) {
            return response()->json(['message' => 'Institution not assigned'], 422);
        }

        $institution = Institution::find($actor->institution_id);
        $institution->update($request->validated());

        return response()->json([
            'message' => 'Institution profile updated',
            'institution' => $institution->fresh(),
        ]);
    }
}
