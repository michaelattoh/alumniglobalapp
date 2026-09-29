<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\AuthLoginRequest;
use App\Http\Requests\Api\AuthRegisterRequest;
use App\Http\Resources\Api\UserResource;
use App\Models\User;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Auth\Events\Verified;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use App\Models\Institution;
use App\Services\NotificationService;
use Illuminate\Auth\Events\PasswordReset;

class AuthController extends Controller
{
    private function deviceMetadata(Request $request): array
    {
        return [
            'platform' => $request->header('X-Platform') ?: null,
            'app_version' => $request->header('X-App-Version') ?: null,
            'device_id' => $request->header('X-Device-Id') ?: null,
        ];
    }

    public function register(AuthRegisterRequest $request, NotificationService $notifications)
    {
        $data = $request->validated();

    $institutionId = null;
    $role = 'alumni';

    // 1) If invitation code is provided, it overrides user_type
    if (!empty($data['code'])) {
        DB::transaction(function () use ($data, &$institutionId, &$role) {
            $invite = \App\Models\InvitationCode::where('code', $data['code'])
                ->lockForUpdate()
                ->first();

            if (!$invite || !$invite->is_active) {
                abort(response()->json(['message' => 'Invalid code'], 422));
            }
            if ($invite->expires_at && now()->greaterThan($invite->expires_at)) {
                abort(response()->json(['message' => 'Code expired'], 422));
            }
            if ($invite->used_count >= $invite->max_uses) {
                abort(response()->json(['message' => 'Code has been used up'], 422));
            }

            $institutionId = $invite->institution_id;
            $role = $invite->role === 'admin' ? 'institution_admin' : $invite->role;

            $invite->increment('used_count');
        });
    } else {
        // 2) No code: use user_type logic
        if ($data['user_type'] === 'school') {
            // If school_name is provided now, create institution immediately.
            if (!empty($data['school_name'])) {
                $institution = Institution::create([
                    'name' => $data['school_name'],
                    'slug' => Str::slug($data['school_name']),
                    'status' => 'pending',
                ]);

                $institutionId = $institution->id;
            }

            $role = 'institution_admin';
        } else {
            // alumni must select institution when any exist
            $institutionCount = Institution::query()->count();
            if ($institutionCount > 0) {
                $selectedInstitutionId = $data['institution_id'] ?? null;
                if (!$selectedInstitutionId) {
                    return response()->json([
                        'message' => 'Validation error',
                        'requires_institution' => true,
                        'errors' => [
                            'institution_id' => ['The institution_id field is required when user_type is alumni.'],
                        ],
                    ], 422);
                }

                $institution = Institution::query()
                    ->where('id', $selectedInstitutionId)
                    ->where('status', 'active')
                    ->first();

                if (!$institution) {
                    return response()->json([
                        'message' => 'Validation error',
                        'requires_institution' => true,
                        'errors' => [
                            'institution_id' => ['Selected institution is invalid or inactive.'],
                        ],
                    ], 422);
                }

                $institutionId = $institution->id;
            }

            $role = 'alumni';
        }
    }

    $user = User::create([
        'name' => $data['name'],
        'email' => $data['email'],
        'password' => Hash::make($data['password']),
        'role' => $role,
        'institution_id' => $institutionId,
    ]);

    $verificationStatus = ($role === 'alumni' && $institutionId) ? 'pending' : 'unverified';
    $verifiedAt = $verificationStatus === 'verified' ? now() : null;

    // Create profile + store phone
    $user->profile()->create([
        'phone' => $data['phone'] ?? null,
        'graduation_year' => $role === 'alumni' ? ($data['graduation_year'] ?? null) : null,
        'verification_status' => $verificationStatus,
        'verified_at' => $verifiedAt,
        'visibility' => 'public',
    ]);

    $requiresEmailVerification = !$user->hasVerifiedEmail();
    try {
        $user->sendEmailVerificationNotification();
    } catch (\Throwable $e) {
        Log::warning('Email verification notification failed on register.', [
            'user_id' => $user->id,
            'error' => $e->getMessage(),
        ]);
    }

    // (Optional) include institution name for school/admin users
    $institutionName = null;
    if ($user->institution_id) {
        $institutionName = optional($user->institution)->name;
    }

    $this->notifySuperAdminsOfRegistration($user, $notifications, $institutionName);
    $this->notifyInstitutionAdminsOfAlumniRegistration($user, $notifications, $institutionName);

        return response()->json([
            'message' => $requiresEmailVerification
                ? 'Please verify your email address to continue.'
                : 'Registration successful.',
            'requires_email_verification' => $requiresEmailVerification,
            'user' => new UserResource($user->load('institution')),
            'institution' => $institutionName,
            'requires_school_verification' => $data['user_type'] === 'school' && !$institutionId,
        ], 201);
    }

    private function notifySuperAdminsOfRegistration(User $user, NotificationService $notifications, ?string $institutionName = null): void
    {
        $superAdminIds = User::query()
            ->where('role', 'super_admin')
            ->pluck('id');

        if ($superAdminIds->isEmpty()) {
            return;
        }

        $type = $user->role === 'institution_admin' ? 'account.school_registered' : 'account.alumni_registered';
        $title = $user->role === 'institution_admin' ? 'New school registration' : 'New alumni registration';
        $body = $user->role === 'institution_admin'
            ? "{$user->name} created a school admin account" . ($institutionName ? " for {$institutionName}." : '.')
            : "{$user->name} created an alumni account" . ($institutionName ? " at {$institutionName}." : '.');

        $payload = array_filter([
            'screen' => 'users',
            'route' => '/super/users',
            'user_id' => (string) $user->id,
            'role' => $user->role,
            'institution_id' => $user->institution_id ? (string) $user->institution_id : null,
            'institution_name' => $institutionName,
        ], static fn ($value) => $value !== null && $value !== '');

        foreach ($superAdminIds as $superAdminId) {
            $notifications->notify((int) $superAdminId, $type, $title, $body, $payload);
        }
    }

    private function notifyInstitutionAdminsOfAlumniRegistration(User $user, NotificationService $notifications, ?string $institutionName = null): void
    {
        if ($user->role !== 'alumni' || !$user->institution_id) {
            return;
        }

        $institutionAdminIds = User::query()
            ->whereIn('role', ['institution_admin', 'admin'])
            ->where('institution_id', $user->institution_id)
            ->pluck('id');

        if ($institutionAdminIds->isEmpty()) {
            return;
        }

        $body = "{$user->name} registered as an alumni" . ($institutionName ? " at {$institutionName}." : '.');
        $payload = array_filter([
            'screen' => 'verification',
            'route' => '/institution/verification',
            'user_id' => (string) $user->id,
            'role' => $user->role,
            'institution_id' => $user->institution_id ? (string) $user->institution_id : null,
            'institution_name' => $institutionName,
        ], static fn ($value) => $value !== null && $value !== '');

        foreach ($institutionAdminIds as $institutionAdminId) {
            $notifications->notify(
                (int) $institutionAdminId,
                'account.alumni_verification_requested',
                'New alumni verification request',
                $body,
                $payload
            );
        }
    }


    public function login(AuthLoginRequest $request)
    {
        $data = $request->validated();

        $user = User::where('email', $data['email'])->first();

        if (!$user || !Hash::check($data['password'], $user->password)) {
            return response()->json(['message' => 'Invalid credentials'], 422);
        }
        if (!$user->hasVerifiedEmail() && $user->role !== 'super_admin') {
            return response()->json([
                'message' => 'Please verify your email address before logging in.',
                'requires_email_verification' => true,
            ], 403);
        }

        // optional: revoke old tokens to keep it simple
        $user->tokens()->delete();

        $token = $user->createToken('mobile')->plainTextToken;
        AuditLog::record($user, 'auth.login', User::class, $user->id, [
            'via' => 'password',
            'role' => $user->role,
            'device' => $this->deviceMetadata($request),
        ], $request);

        return response()->json([
            'token' => $token,
            'user' => new UserResource($user->load('institution')),
        ]);
    }

    public function resendVerification(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
        ]);

        $user = User::where('email', $data['email'])->first();
        if (!$user) {
            return response()->json(['message' => 'If that email exists, a link will be sent.']);
        }
        if ($user->hasVerifiedEmail()) {
            return response()->json(['message' => 'Email already verified.']);
        }

        $user->sendEmailVerificationNotification();

        return response()->json(['message' => 'Verification link sent.']);
    }

    public function verifyEmail(Request $request, string $id, string $hash)
    {
        $user = User::findOrFail($id);

        if (!hash_equals(sha1($user->getEmailForVerification()), $hash)) {
            if ($request->wantsJson()) {
                return response()->json(['message' => 'Invalid verification link.'], 403);
            }
            return view('auth.verify', [
                'status' => 'invalid',
                'email' => $user->email,
            ]);
        }

        if (!$user->hasVerifiedEmail()) {
            $user->markEmailAsVerified();
            event(new Verified($user));
        }

        if ($request->wantsJson()) {
            return response()->json(['message' => 'Email verified']);
        }

        return view('auth.verify', [
            'status' => $user->hasVerifiedEmail() ? 'verified' : 'invalid',
            'email' => $user->email,
        ]);
    }

    public function forgotPassword(Request $request)
    {
        $request->validate(['email' => ['required', 'email']]);

        $status = Password::sendResetLink($request->only('email'));

        return $status === Password::RESET_LINK_SENT
            ? response()->json(['message' => __($status)])
            : response()->json(['message' => __($status)], 422);
    }

    public function resetPassword(Request $request)
    {
        $request->validate([
            'token' => ['required'],
            'email' => ['required', 'email'],
            'password' => ['required', 'min:8', 'confirmed'],
        ]);

        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (User $user, string $password) {
                $user->forceFill([
                    'password' => Hash::make($password),
                ])->save();

                event(new PasswordReset($user));
            }
        );

        return $status === Password::PASSWORD_RESET
            ? response()->json(['message' => __($status)])
            : response()->json(['message' => __($status)], 422);
    }

    public function showResetForm(Request $request, string $token)
    {
        return view('auth.reset', [
            'token' => $token,
            'email' => $request->query('email'),
        ]);
    }

    public function resetPasswordWeb(Request $request)
    {
        $request->validate([
            'token' => ['required'],
            'email' => ['required', 'email'],
            'password' => ['required', 'min:8', 'confirmed'],
        ]);

        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (User $user, string $password) {
                $user->forceFill([
                    'password' => Hash::make($password),
                ])->save();

                event(new PasswordReset($user));
            }
        );

        if ($status === Password::PASSWORD_RESET) {
            return view('auth.reset_success');
        }

        return view('auth.reset', [
            'token' => $request->input('token'),
            'email' => $request->input('email'),
            'error' => __($status),
        ]);
    }

    public function logout(Request $request)
    {
        $user = $request->user();
        $request->user()->currentAccessToken()->delete();
        if ($user) {
            AuditLog::record($user, 'auth.logout', User::class, $user->id, [
                'role' => $user->role,
                'device' => $this->deviceMetadata($request),
            ], $request);
        }

        return response()->json(['message' => 'Logged out']);
    }
}
