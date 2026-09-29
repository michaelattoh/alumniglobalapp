<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\SystemSettingUpdateRequest;
use App\Http\Resources\Api\SystemSettingResource;
use App\Models\AuditLog;
use App\Models\SystemSetting;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;

class SystemSettingController extends Controller
{
    private function defaultPermissionMap(): array
    {
        return [
            'manage_announcements' => true,
            'manage_events' => true,
            'manage_jobs' => true,
            'manage_donations' => true,
            'manage_ads' => true,
            'manage_support_queue' => true,
            'manage_moderation' => true,
            'view_audit_logs' => true,
            'view_users' => true,
            'view_transactions' => true,
            'manage_receipts' => true,
            'view_subscriptions' => true,
        ];
    }

    private function defaultRoleCatalog(): array
    {
        $all = $this->defaultPermissionMap();

        return [
            'institution_admin' => [
                'label' => 'Institution Admin',
                'portal' => 'admin',
                'permissions' => array_merge($all, [
                    'view_transactions' => false,
                    'manage_receipts' => false,
                    'view_subscriptions' => false,
                ]),
            ],
            'accountant' => [
                'label' => 'Accountant',
                'portal' => 'accounting',
                'permissions' => array_merge(array_fill_keys(array_keys($all), false), [
                    'manage_support_queue' => true,
                    'view_transactions' => true,
                    'manage_receipts' => true,
                    'view_subscriptions' => true,
                ]),
            ],
            'support_agent' => [
                'label' => 'Customer Support',
                'portal' => 'support',
                'permissions' => array_merge(array_fill_keys(array_keys($all), false), [
                    'view_users' => true,
                    'manage_support_queue' => true,
                ]),
            ],
        ];
    }

    private function mergedRoleCatalog(): array
    {
        $rawCatalog = SystemSetting::query()->where('key', 'role_catalog')->value('value');
        $catalog = is_array($rawCatalog) ? $rawCatalog : [];
        $defaults = $this->defaultRoleCatalog();

        foreach ($defaults as $role => $config) {
            $stored = is_array($catalog[$role] ?? null) ? $catalog[$role] : [];
            $catalog[$role] = [
                'label' => (string) ($stored['label'] ?? $config['label']),
                'portal' => in_array(($stored['portal'] ?? $config['portal']), ['admin', 'accounting', 'support'], true)
                    ? ($stored['portal'] ?? $config['portal'])
                    : $config['portal'],
                'permissions' => array_merge(
                    $config['permissions'],
                    is_array($stored['permissions'] ?? null) ? $stored['permissions'] : []
                ),
            ];
        }

        return $catalog;
    }

    public function index(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $settings = SystemSetting::query()->get();

        return response()->json([
            'data' => SystemSettingResource::collection($settings)->resolve(),
        ]);
    }

    public function roleConfig(Request $request)
    {
        $actor = $request->user();
        if (!$actor) {
            return response()->json(['message' => 'Unauthenticated'], 401);
        }

        return response()->json([
            'data' => [
                'permissions' => $this->defaultPermissionMap(),
                'roles' => $this->mergedRoleCatalog(),
            ],
        ]);
    }

    public function update(SystemSettingUpdateRequest $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $payload = $request->validated()['settings'];
        $updated = [];

        foreach ($payload as $key => $value) {
            $setting = SystemSetting::updateOrCreate(
                ['key' => $key],
                ['value' => $value, 'updated_by' => $actor->id]
            );
            $updated[] = $setting;
        }

        AuditLog::record($actor, 'settings.updated', SystemSetting::class, null, [
            'keys' => array_keys($payload),
        ], $request);

        return response()->json([
            'message' => 'Settings updated',
            'data' => SystemSettingResource::collection($updated)->resolve(),
        ]);
    }

    public function testEmail(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'email' => ['required', 'email'],
        ]);

        $template = SystemSetting::query()->where('key', 'email_test_template')->value('value');
        $subject = is_array($template) ? ($template['subject'] ?? null) : null;
        $body = is_array($template) ? ($template['body'] ?? null) : null;
        $subject = $subject ?: 'Alumni Global: Test Email';
        $body = $body ?: 'This is a test email from Alumni Global Admin.';

        $platformName = SystemSetting::query()->where('key', 'app_name')->value('value');
        $senderName = SystemSetting::query()->where('key', 'email_sender_name')->value('value');
        $senderEmail = SystemSetting::query()->where('key', 'email_sender_address')->value('value');
        $smtpHost = SystemSetting::query()->where('key', 'smtp_host')->value('value');
        $smtpPort = SystemSetting::query()->where('key', 'smtp_port')->value('value');
        $smtpUser = SystemSetting::query()->where('key', 'smtp_username')->value('value');
        $smtpPass = SystemSetting::query()->where('key', 'smtp_password')->value('value');
        $smtpEnc = SystemSetting::query()->where('key', 'smtp_encryption')->value('value');
        $variables = [
            '{admin_name}' => $actor->name ?? 'Admin',
            '{email}' => $data['email'],
            '{date}' => now()->toDateTimeString(),
            '{platform_name}' => is_string($platformName) && $platformName !== '' ? $platformName : 'Alumni Global',
        ];
        $subject = str_replace(array_keys($variables), array_values($variables), $subject);
        $body = str_replace(array_keys($variables), array_values($variables), $body);

        if ($smtpHost && $smtpPort) {
            config([
                'mail.default' => 'smtp',
                'mail.mailers.smtp.host' => $smtpHost,
                'mail.mailers.smtp.port' => (int) $smtpPort,
                'mail.mailers.smtp.encryption' => $smtpEnc ?: null,
                'mail.mailers.smtp.username' => $smtpUser ?: null,
                'mail.mailers.smtp.password' => $smtpPass ?: null,
            ]);
        }
        if ($senderEmail) {
            config([
                'mail.from.address' => $senderEmail,
                'mail.from.name' => $senderName ?: 'Alumni Global',
            ]);
        }

        Mail::html(nl2br(e($body)), function ($message) use ($data, $subject) {
            $message->to($data['email'])
                ->subject($subject);
        });

        return response()->json(['message' => 'Test email sent']);
    }
}
