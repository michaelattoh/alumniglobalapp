<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\AttachInstitutionRequest;
use App\Http\Requests\Api\MeUpdateRequest;
use App\Http\Resources\Api\InstitutionMembershipResource;
use App\Http\Resources\Api\ProfileResource;
use App\Http\Resources\Api\UserResource;
use App\Models\InvitationCode;
use App\Models\StudentId;
use App\Models\Post;
use App\Models\Story;
use App\Models\Donation;
use App\Models\EventRsvp;
use Illuminate\Support\Str;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MeController extends Controller
{
    public function show(Request $request)
    {
        $user = $request->user()->load([
            'institution',
            'profile',
            'memberships.institution',
        ]);

        return response()->json([
            'user' => new UserResource($user),
            'profile' => new ProfileResource($user->profile),
            'memberships' => InstitutionMembershipResource::collection(
                $user->memberships
                    ->where('status', 'approved')
                    ->values()
            ),
        ]);
    }

    public function update(MeUpdateRequest $request)
    {
        $data = $request->validated();
        $user = $request->user();

        // 1) Update user fields (only name for now)
        if (array_key_exists('name', $data)) {
            $user->name = $data['name'];
            $user->save();
        }

        // 2) Update profile fields
        $profileFields = collect($data)->only([
            'headline',
            'bio',
            'avatar_url',
            'location',
            'phone',
            'graduation_year',
            'program',
            'department',
            'current_company',
            'current_role',
            'industry',
            'career_focus',
            'skills',
            'interests',
            'visibility',
        ])->toArray();

        // Ensure profile exists (your register creates it, but this keeps it safe)
        $profile = $user->profile()->firstOrCreate(
            [],
            [
                'verification_status' => 'unverified',
                'visibility' => 'public',
            ]
        );

        if (!empty($profileFields)) {
            $profile->fill($profileFields);
            $profile->save();
        }

        // Return updated data (Flutter-friendly)
        $user->load(['institution', 'profile', 'memberships.institution']);

        return response()->json([
            'message' => 'Updated',
            'user' => new UserResource($user),
            'profile' => new ProfileResource($user->profile),
            'memberships' => InstitutionMembershipResource::collection(
                $user->memberships
                    ->where('status', 'approved')
                    ->values()
            ),
        ]);
    }

    public function export(Request $request)
    {
        $user = $request->user();

        $user->load(['institution', 'profile', 'memberships.institution']);

        $posts = Post::where('user_id', $user->id)->latest()->get();
        $stories = Story::where('user_id', $user->id)->latest()->get();
        $donations = Donation::where('user_id', $user->id)->latest()->get();
        $rsvps = EventRsvp::where('user_id', $user->id)->latest()->get();

        return response()->json([
            'user' => new UserResource($user),
            'profile' => new ProfileResource($user->profile),
            'memberships' => InstitutionMembershipResource::collection(
                $user->memberships
                    ->where('status', 'approved')
                    ->values()
            ),
            'posts' => $posts,
            'stories' => $stories,
            'donations' => $donations,
            'rsvps' => $rsvps,
        ]);
    }

    public function destroy(Request $request)
    {
        $user = $request->user();
        $timestamp = now()->format('YmdHis');
        $placeholderEmail = "deleted_{$user->id}_{$timestamp}@example.invalid";

        $user->update([
            'name' => 'Deleted User',
            'email' => $placeholderEmail,
            'status' => 'deleted',
            'remember_token' => null,
        ]);

        $user->profile()->update([
            'headline' => null,
            'bio' => null,
            'avatar_url' => null,
            'location' => null,
            'phone' => null,
            'graduation_year' => null,
            'program' => null,
            'department' => null,
            'current_company' => null,
            'current_role' => null,
            'industry' => null,
            'career_focus' => null,
            'skills' => [],
            'interests' => [],
        ]);

        return response()->json(['message' => 'Account deleted']);
    }

    public function attachInstitution(AttachInstitutionRequest $request)
    {
        $data = $request->validated();

        $user = $request->user();

        // Only alumni should use this flow (optional rule)
        if ($user->role !== 'alumni') {
            return response()->json(['message' => 'Only alumni accounts can attach an institution.'], 403);
        }

        DB::transaction(function () use ($data, $user) {
            $invite = InvitationCode::where('code', $data['code'])
                ->lockForUpdate()
                ->first();

            if ($invite) {
                if (!$invite->is_active) {
                    abort(response()->json(['message' => 'Invalid code'], 422));
                }
                if ($invite->expires_at && now()->greaterThan($invite->expires_at)) {
                    abort(response()->json(['message' => 'Code expired'], 422));
                }
                if ($invite->used_count >= $invite->max_uses) {
                    abort(response()->json(['message' => 'Code has been used up'], 422));
                }

                $user->institution_id = $invite->institution_id;
                $user->save();

                $profile = $user->profile()->firstOrCreate(
                    [],
                    [
                        'verification_status' => 'unverified',
                        'visibility' => 'public',
                    ]
                );

                $profile->verification_status = 'pending';
                $profile->visibility = 'institution_only';
                $profile->save();

                $invite->increment('used_count');
                return;
            }

            $studentId = StudentId::where('code', $data['code'])
                ->lockForUpdate()
                ->first();

            if (!$studentId || $studentId->status !== 'issued') {
                abort(response()->json(['message' => 'Invalid code'], 422));
            }

            if ($studentId->user_id && (int) $studentId->user_id !== (int) $user->id) {
                abort(response()->json(['message' => 'Code is not assigned to this user'], 403));
            }

            $user->institution_id = $studentId->institution_id;
            $user->save();

            $profile = $user->profile()->firstOrCreate(
                [],
                [
                    'verification_status' => 'unverified',
                    'visibility' => 'public',
                ]
            );

            $profile->verification_status = 'pending';
            $profile->visibility = 'institution_only';
            $profile->save();

            $studentId->update([
                'status' => 'used',
                'used_at' => now(),
                'user_id' => $user->id,
            ]);
        });

        $user->load(['institution', 'profile', 'memberships.institution']);

        return response()->json([
            'message' => 'Institution attached. Verification is pending.',
            'user' => new UserResource($user),
            'profile' => new ProfileResource($user->profile),
            'memberships' => InstitutionMembershipResource::collection(
                $user->memberships
                    ->where('status', 'approved')
                    ->values()
            ),
        ]);
    }

}
