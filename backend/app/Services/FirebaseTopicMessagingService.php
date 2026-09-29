<?php

namespace App\Services;

use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Http;
use RuntimeException;

class FirebaseTopicMessagingService
{
    private const GOOGLE_OAUTH_AUDIENCE = 'https://oauth2.googleapis.com/token';
    private const GOOGLE_MESSAGING_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function sendToTopic(string $topic, string $title, ?string $body = null, array $data = []): array
    {
        return $this->sendRawMessage([
            'topic' => $topic,
            ...$this->buildMessagePayload($title, $body, $data),
        ]);
    }

    public function sendToToken(string $token, string $title, ?string $body = null, array $data = []): array
    {
        return $this->sendRawMessage([
            'token' => $token,
            ...$this->buildMessagePayload($title, $body, $data),
        ]);
    }

    private function buildMessagePayload(string $title, ?string $body = null, array $data = []): array
    {
        $message = [
            'notification' => array_filter([
                'title' => $title,
                'body' => $body,
            ], static fn ($value) => $value !== null && $value !== ''),
            'android' => [
                'priority' => 'high',
                'notification' => [
                    'sound' => 'default',
                ],
            ],
            'apns' => [
                'payload' => [
                    'aps' => [
                        'sound' => 'default',
                    ],
                ],
            ],
        ];

        if ($data !== []) {
            $message['data'] = collect($data)
                ->mapWithKeys(fn ($value, $key) => [(string) $key => is_scalar($value) ? (string) $value : json_encode($value)])
                ->all();
        }

        return $message;
    }

    private function sendRawMessage(array $message): array
    {
        $projectId = $this->projectId();
        $accessToken = $this->accessToken();

        $response = Http::withToken($accessToken)
            ->acceptJson()
            ->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", [
                'message' => $message,
            ]);

        if ($response->failed()) {
            throw new RuntimeException($response->json('error.message') ?: 'Unable to send Firebase notification.');
        }

        return $response->json();
    }

    private function accessToken(): string
    {
        $credentials = $this->credentials();
        $issuedAt = now()->timestamp;

        $jwt = JWT::encode([
            'iss' => $credentials['client_email'],
            'scope' => self::GOOGLE_MESSAGING_SCOPE,
            'aud' => self::GOOGLE_OAUTH_AUDIENCE,
            'iat' => $issuedAt,
            'exp' => $issuedAt + 3600,
        ], $credentials['private_key'], 'RS256');

        $response = Http::asForm()->post(self::GOOGLE_OAUTH_AUDIENCE, [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt,
        ]);

        if ($response->failed() || !$response->json('access_token')) {
            throw new RuntimeException('Unable to obtain Firebase access token.');
        }

        return $response->json('access_token');
    }

    private function credentials(): array
    {
        $jsonPath = config('services.firebase.credentials_json');

        if ($jsonPath && is_file($jsonPath)) {
            $decoded = json_decode((string) file_get_contents($jsonPath), true);
            if (is_array($decoded)) {
                return $this->normalizeCredentials($decoded);
            }
        }

        return $this->normalizeCredentials([
            'project_id' => config('services.firebase.project_id'),
            'client_email' => config('services.firebase.client_email'),
            'private_key' => config('services.firebase.private_key'),
        ]);
    }

    private function normalizeCredentials(array $credentials): array
    {
        $projectId = $credentials['project_id'] ?? null;
        $clientEmail = $credentials['client_email'] ?? null;
        $privateKey = $credentials['private_key'] ?? null;

        if (!$projectId || !$clientEmail || !$privateKey) {
            throw new RuntimeException('Firebase credentials are incomplete.');
        }

        return [
            'project_id' => $projectId,
            'client_email' => $clientEmail,
            'private_key' => str_replace('\n', "\n", $privateKey),
        ];
    }

    private function projectId(): string
    {
        $projectId = config('services.firebase.project_id');

        if ($projectId) {
            return $projectId;
        }

        return $this->credentials()['project_id'];
    }
}
