<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SocialAccount;
use App\Models\User;
use App\Models\AuditLog;
use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Google_Client;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class SocialAuthController extends Controller
{
    private function deviceMetadata(Request $request): array
    {
        return [
            'platform' => $request->header('X-Platform') ?: null,
            'app_version' => $request->header('X-App-Version') ?: null,
            'device_id' => $request->header('X-Device-Id') ?: null,
        ];
    }
    public function google(Request $request)
    {
        $data = $request->validate([
            'id_token' => ['required','string'],
            'code' => ['nullable','string'], // invitation code (optional)
        ]);

        [$providerUserId, $email, $name] = $this->verifyGoogleIdToken($data['id_token']);

        return $this->loginOrCreateUser($request, 'google', $providerUserId, $email, $name);
    }

    public function apple(Request $request)
    {
        $data = $request->validate([
            'id_token' => ['required','string'],
            'name' => ['nullable','string','max:120'], // Apple may provide name only once
        ]);

        [$providerUserId, $email] = $this->verifyAppleIdToken($data['id_token']);
        $name = $data['name'] ?? 'User';

        return $this->loginOrCreateUser($request, 'apple', $providerUserId, $email, $name);
    }

    private function loginOrCreateUser(Request $request, string $provider, string $providerUserId, string $email, string $name)
    {
        return DB::transaction(function () use ($request, $provider, $providerUserId, $email, $name) {
            $account = SocialAccount::where('provider', $provider)
                ->where('provider_user_id', $providerUserId)
                ->first();

            if ($account) {
                $user = $account->user;
            } else {
                // Link to existing account if same email exists
                $user = User::where('email', $email)->first();

                if (!$user) {
                    $user = User::create([
                        'name' => $name,
                        'email' => $email,
                        'password' => bcrypt(Str::random(40)),
                        'role' => 'alumni',
                        'institution_id' => null,
                        'status' => 'active',
                    ]);

                    $user->profile()->create([
                        'visibility' => 'public',
                        'verification_status' => 'unverified',
                    ]);
                }

                SocialAccount::create([
                    'user_id' => $user->id,
                    'provider' => $provider,
                    'provider_user_id' => $providerUserId,
                ]);
            }

            // Social login emails can be treated as verified
            if (!$user->hasVerifiedEmail()) {
                $user->forceFill(['email_verified_at' => now()])->save();
            }

            // Block suspended accounts
            if (($user->status ?? 'active') === 'suspended') {
                return response()->json(['message' => 'Account suspended'], 403);
            }

            // Optional: keep one active token
            $user->tokens()->delete();
            $token = $user->createToken('mobile')->plainTextToken;

            AuditLog::record($user, 'auth.login', User::class, $user->id, [
                'via' => $provider,
                'role' => $user->role,
                'device' => $this->deviceMetadata($request),
            ], $request);

            return response()->json([
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role' => $user->role,
                    'institution_id' => $user->institution_id,
                ],
            ]);
        });
    }

    private function verifyGoogleIdToken(string $idToken): array
    {
        $clientId = config('services.google.client_id');
        if (!$clientId) {
            abort(response()->json(['message' => 'GOOGLE_CLIENT_ID not configured'], 500));
        }

        $client = new Google_Client(['client_id' => $clientId]);
        $payload = $client->verifyIdToken($idToken);

        if (!$payload) {
            abort(response()->json(['message' => 'Invalid Google token'], 422));
        }

        $providerUserId = $payload['sub'] ?? null;
        $email = $payload['email'] ?? null;
        $name = $payload['name'] ?? 'User';

        if (!$providerUserId || !$email) {
            abort(response()->json(['message' => 'Google token missing required claims'], 422));
        }

        return [$providerUserId, $email, $name];
    }

    private function verifyAppleIdToken(string $idToken): array
    {
        $audience = config('services.apple.client_id');
        if (!$audience) {
            abort(response()->json(['message' => 'APPLE_CLIENT_ID not configured'], 500));
        }

        $jwks = Cache::remember('apple_jwks', now()->addHours(12), function () {
            $res = Http::timeout(10)->get('https://appleid.apple.com/auth/keys');
            if (!$res->ok()) {
                abort(response()->json(['message' => 'Unable to fetch Apple public keys'], 500));
            }
            return $res->json();
        });

        try {
            $decoded = JWT::decode($idToken, JWK::parseKeySet($jwks));
        } catch (\Throwable $e) {
            abort(response()->json(['message' => 'Invalid Apple token'], 422));
        }

        // Validate standard Apple claims
        if (($decoded->iss ?? null) !== 'https://appleid.apple.com') {
            abort(response()->json(['message' => 'Invalid Apple issuer'], 422));
        }
        if (($decoded->aud ?? null) !== $audience) {
            abort(response()->json(['message' => 'Invalid Apple audience'], 422));
        }

        $providerUserId = $decoded->sub ?? null;
        $email = $decoded->email ?? null;

        if (!$providerUserId) {
            abort(response()->json(['message' => 'Apple token missing subject'], 422));
        }
        // Email can be hidden/relay depending on user settings, but is usually present.
        if (!$email) {
            $email = "apple_user_{$providerUserId}@example.local";
        }

        return [$providerUserId, $email];
    }
}
