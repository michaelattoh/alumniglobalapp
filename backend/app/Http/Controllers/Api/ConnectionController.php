<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\ConnectionRespondRequest;
use App\Http\Requests\Api\ConnectionSendRequest;
use App\Http\Resources\Api\ConnectionRequestResource;
use App\Models\ConnectionRequest;
use App\Models\User;
use App\Models\UserBlock;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\HtmlString;

class ConnectionController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();
        $perPage = (int) $request->query('per_page', 20);

        $sent = ConnectionRequest::where('from_user_id', $user->id)
            ->with('toUser:id,name,email,institution_id', 'toUser.profile:id,user_id,avatar_url')
            ->latest()
            ->paginate($perPage, ['*'], 'sent_page');
        $received = ConnectionRequest::where('to_user_id', $user->id)
            ->with('fromUser:id,name,email,institution_id', 'fromUser.profile:id,user_id,avatar_url')
            ->latest()
            ->paginate($perPage, ['*'], 'received_page');

        return response()->json([
            'sent' => [
                'data' => ConnectionRequestResource::collection(collect($sent->items()))->resolve(),
                'meta' => $this->paginationMeta($sent),
            ],
            'received' => [
                'data' => ConnectionRequestResource::collection(collect($received->items()))->resolve(),
                'meta' => $this->paginationMeta($received),
            ],
        ]);
    }

    public function send(ConnectionSendRequest $request, User $user, NotificationService $notificationService)
    {
        $actor = $request->user();

        if ((int) $actor->id === (int) $user->id) {
            return response()->json(['message' => 'Cannot connect to yourself'], 422);
        }

        if ($this->isBlockedEitherWay($actor->id, $user->id)) {
            return response()->json(['message' => 'Connection not allowed'], 403);
        }

        $data = $request->validated();
        $source = $data['source'] ?? 'connection';

        $connection = ConnectionRequest::updateOrCreate(
            ['from_user_id' => $actor->id, 'to_user_id' => $user->id],
            [
                'status' => 'pending',
                'message' => $data['message'] ?? null,
                'source' => $source,
                'responded_at' => null,
            ]
        );

        $notificationService->notify(
            $user->id,
            'connection_request',
            $source === 'mentorship' ? 'New mentorship request' : 'New connection request',
            $source === 'mentorship'
                ? $actor->name . ' wants to connect for mentorship.'
                : $actor->name . ' sent you a connection request.',
            [
                'from_user_id' => $actor->id,
                'from_user_name' => $actor->name,
                'connection_id' => $connection->id,
                'source' => $source,
                'screen' => $source === 'mentorship' ? 'mentorship' : 'network',
            ]
        );

        $this->sendConnectionRequestEmail(
            $user->email,
            $user->name,
            $actor->name
        );

        return response()->json([
            'message' => 'Connection request sent',
            'connection' => new ConnectionRequestResource($connection->load([
                'toUser:id,name,email,institution_id',
                'toUser.profile:id,user_id,avatar_url',
                'fromUser:id,name,email,institution_id',
                'fromUser.profile:id,user_id,avatar_url',
            ])),
        ], 201);
    }

    public function respond(ConnectionRespondRequest $request, ConnectionRequest $connection, NotificationService $notificationService)
    {
        $actor = $request->user();
        if ((int) $connection->to_user_id !== (int) $actor->id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();

        $connection->update([
            'status' => $data['status'],
            'responded_at' => now(),
        ]);
        $source = $connection->source ?: 'connection';

        $notificationService->notify(
            $connection->from_user_id,
            'connection_response',
            $source === 'mentorship'
                ? 'Mentorship request ' . $data['status']
                : 'Connection request ' . $data['status'],
            $source === 'mentorship'
                ? $actor->name . ' ' . $data['status'] . ' your mentorship request.'
                : $actor->name . ' ' . $data['status'] . ' your connection request.',
            [
                'connection_id' => $connection->id,
                'from_user_id' => $actor->id,
                'from_user_name' => $actor->name,
                'source' => $source,
                'screen' => $source === 'mentorship' ? 'mentorship' : 'network',
            ]
        );

        if ($data['status'] === 'accepted') {
            $fromUser = User::query()->find($connection->from_user_id);
            $toUser = User::query()->find($connection->to_user_id);

            $notificationService->notify(
                $connection->to_user_id,
                'connection_accepted',
                $source === 'mentorship' ? 'Mentorship connection established' : 'Connection established',
                $source === 'mentorship'
                    ? 'You are now connected for mentorship with ' . ($fromUser?->name ?? 'a member') . '.'
                    : 'You are now connected with ' . ($fromUser?->name ?? 'a member') . '.',
                [
                    'connection_id' => $connection->id,
                    'from_user_id' => $connection->from_user_id,
                    'from_user_name' => $fromUser?->name,
                    'source' => $source,
                    'screen' => $source === 'mentorship' ? 'mentorship' : 'network',
                ]
            );

            if ($fromUser && $toUser) {
                $this->sendConnectionEmail(
                    $fromUser->email,
                    $fromUser->name,
                    $toUser->name
                );
                $this->sendConnectionEmail(
                    $toUser->email,
                    $toUser->name,
                    $fromUser->name
                );
            }
        }

        return response()->json([
            'message' => 'Connection request updated',
            'connection' => new ConnectionRequestResource($connection->load([
                'toUser:id,name,email,institution_id',
                'toUser.profile:id,user_id,avatar_url',
                'fromUser:id,name,email,institution_id',
                'fromUser.profile:id,user_id,avatar_url',
            ])),
        ]);
    }

    private function isBlockedEitherWay(int $a, int $b): bool
    {
        return UserBlock::where('blocker_id', $a)->where('blocked_id', $b)->exists()
            || UserBlock::where('blocker_id', $b)->where('blocked_id', $a)->exists();
    }

    private function sendConnectionEmail(string $email, string $recipientName, string $otherName): void
    {
        try {
            $fromEmail = config('mail.from.address', 'no-reply@alumniglobalnetwork.com');
            $fromName = config('mail.from.name', 'Alumni Global Network');

            Mail::html(
                $this->connectionEmailHtml(
                    headline: 'You\'re connected',
                    greetingName: $recipientName,
                    body: "You are now connected with {$otherName} on Alumni Global Network.",
                    cta: 'Open the app to start chatting, networking, and building your alumni circle.',
                    actionUrl: $this->appGatewayUrl('messages'),
                    actionLabel: 'Open Alumni Global Network',
                ),
                function ($message) use ($email, $fromEmail, $fromName) {
                    $message
                        ->to($email)
                        ->from($fromEmail, $fromName)
                        ->subject('New connection on Alumni Global Network');
                }
            );
        } catch (\Throwable $e) {
            Log::warning('Failed to send connection email', [
                'email' => $email,
                'error' => $e->getMessage(),
            ]);
        }
    }

    private function sendConnectionRequestEmail(string $email, string $recipientName, string $requesterName): void
    {
        try {
            $fromEmail = config('mail.from.address', 'no-reply@alumniglobalnetwork.com');
            $fromName = config('mail.from.name', 'Alumni Global Network');

            Mail::html(
                $this->connectionEmailHtml(
                    headline: 'New connection request',
                    greetingName: $recipientName,
                    body: "{$requesterName} sent you a connection request on Alumni Global Network.",
                    cta: 'Open the app to accept or decline and keep the conversation moving.',
                    actionUrl: $this->appGatewayUrl('network'),
                    actionLabel: 'Open the app',
                ),
                function ($message) use ($email, $fromEmail, $fromName) {
                    $message
                        ->to($email)
                        ->from($fromEmail, $fromName)
                        ->subject('New connection request on Alumni Global Network');
                }
            );
        } catch (\Throwable $e) {
            Log::warning('Failed to send connection request email', [
                'email' => $email,
                'error' => $e->getMessage(),
            ]);
        }
    }

    private function connectionEmailHtml(
        string $headline,
        string $greetingName,
        string $body,
        string $cta,
        string $actionUrl,
        string $actionLabel
    ): string {
        $appStoreUrl = 'https://apps.apple.com/app/global-alumni-network/id6759199673';
        $playStoreUrl = 'https://play.google.com/store/apps/details?id=com.alumniglobalnetwork.app';

        return '
            <div style="background:#f8fafc;padding:32px 16px;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#0f172a;">
                <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:24px;overflow:hidden;border:1px solid #e2e8f0;">
                    <div style="padding:28px;background:linear-gradient(135deg,#0f172a,#2563eb);color:#ffffff;">
                        <div style="font-size:13px;letter-spacing:.08em;text-transform:uppercase;opacity:.82;">Alumni Global Network</div>
                        <div style="margin-top:12px;font-size:28px;font-weight:800;line-height:1.2;">'.$headline.'</div>
                    </div>
                    <div style="padding:28px 28px 24px;">
                        <p style="margin:0 0 14px;font-size:16px;line-height:1.6;">Hello '.e($greetingName).',</p>
                        <p style="margin:0 0 14px;font-size:16px;line-height:1.7;color:#334155;">'.e($body).'</p>
                        <div style="margin:20px 0;padding:16px 18px;background:#eff6ff;border-radius:18px;color:#1d4ed8;font-size:15px;line-height:1.6;font-weight:600;">'.e($cta).'</div>
                        <div style="margin:20px 0 10px;">
                            <a href="'.e($actionUrl).'" style="display:inline-block;padding:14px 22px;border-radius:999px;background:#2563eb;color:#ffffff;font-size:15px;font-weight:700;text-decoration:none;">'.e($actionLabel).'</a>
                        </div>
                        <p style="margin:12px 0 0;font-size:13px;line-height:1.7;color:#64748b;">
                            If the button does not open the app, update or install it here:
                            <a href="'.e($appStoreUrl).'" style="color:#2563eb;text-decoration:none;font-weight:600;">App Store</a>
                            ·
                            <a href="'.e($playStoreUrl).'" style="color:#2563eb;text-decoration:none;font-weight:600;">Google Play</a>
                        </p>
                        <p style="margin:18px 0 0;font-size:14px;line-height:1.7;color:#64748b;">Thanks for growing your network with Alumni Global Network.</p>
                    </div>
                </div>
            </div>
        ';
    }

    private function appOpenUrl(string $destination): string
    {
        return sprintf('alumniglobal://open/%s', $destination);
    }

    private function appGatewayUrl(string $destination): string
    {
        return url(sprintf('/open-app/%s', $destination === 'messages' ? 'messages' : 'network'));
    }

    public function openApp(string $destination)
    {
        $screen = $destination === 'messages' ? 'messages' : 'network';
        $deepLink = $this->appOpenUrl($screen);
        $appStoreUrl = 'https://apps.apple.com/app/global-alumni-network/id6759199673';
        $playStoreUrl = 'https://play.google.com/store/apps/details?id=com.alumniglobalnetwork.app';
        $deepLinkJson = json_encode($deepLink, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);
        $appStoreJson = json_encode($appStoreUrl, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);
        $playStoreJson = json_encode($playStoreUrl, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_AMP | JSON_HEX_QUOT);

        $html = <<<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Open Alumni Global Network</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f8fafc; color: #0f172a; margin: 0; }
    .wrap { max-width: 560px; margin: 0 auto; padding: 40px 20px; text-align: center; }
    .card { background: #fff; border-radius: 24px; box-shadow: 0 20px 40px rgba(15, 23, 42, 0.08); padding: 32px 24px; }
    h1 { margin: 0 0 10px; font-size: 28px; }
    p { margin: 0 0 18px; color: #475569; line-height: 1.6; }
    .btn { display: inline-block; margin: 8px 6px; padding: 14px 20px; border-radius: 999px; text-decoration: none; font-weight: 600; }
    .primary { background: #1d4ed8; color: #fff; }
    .secondary { background: #e2e8f0; color: #0f172a; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>Opening Alumni Global Network</h1>
      <p>If the app does not open automatically, tap the button below or install the latest version.</p>
      <p>
        <a class="btn primary" href="{$deepLink}">Open the app</a>
      </p>
      <p>
        <a class="btn secondary" href="{$appStoreUrl}">App Store</a>
        <a class="btn secondary" href="{$playStoreUrl}">Google Play</a>
      </p>
    </div>
  </div>
  <script>
    const deepLink = {$deepLinkJson};
    const appStoreUrl = {$appStoreJson};
    const playStoreUrl = {$playStoreJson};
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    const fallbackUrl = isIOS ? appStoreUrl : playStoreUrl;
    window.setTimeout(() => {
      window.location.href = deepLink;
    }, 120);
    window.setTimeout(() => {
      if (document.visibilityState === 'visible') {
        window.location.href = fallbackUrl;
      }
    }, 1800);
  </script>
</body>
</html>
HTML;

        return response(new HtmlString($html));
    }
}
