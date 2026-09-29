<?php

namespace App\Services;

use App\Models\NewsletterSubscriber;
use App\Models\SystemSetting;
use Illuminate\Support\Facades\Mail;

class NewsletterService
{
    public function sendLaunch(?string $subjectOverride = null, ?string $bodyOverride = null): int
    {
        $subject = $subjectOverride
            ?: (SystemSetting::query()->where('key', 'newsletter_launch_subject')->value('value') ?: 'Alumni Global is launching soon');
        $body = $bodyOverride
            ?: (SystemSetting::query()->where('key', 'newsletter_launch_body')->value('value') ?: 'Thanks for joining our waitlist. We will be launching soon. Stay tuned.');

        $platformName = SystemSetting::query()->where('key', 'app_name')->value('value');
        $senderName = SystemSetting::query()->where('key', 'email_sender_name')->value('value');
        $senderEmail = SystemSetting::query()->where('key', 'email_sender_address')->value('value');
        $smtpHost = SystemSetting::query()->where('key', 'smtp_host')->value('value');
        $smtpPort = SystemSetting::query()->where('key', 'smtp_port')->value('value');
        $smtpUser = SystemSetting::query()->where('key', 'smtp_username')->value('value');
        $smtpPass = SystemSetting::query()->where('key', 'smtp_password')->value('value');
        $smtpEnc = SystemSetting::query()->where('key', 'smtp_encryption')->value('value');
        $baseUrl = rtrim(config('app.url') ?: 'https://www.alumniglobalnetwork.com', '/');

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

        $subject = str_replace('{platform_name}', $platformName ?: 'Alumni Global', $subject);

        $subscribers = NewsletterSubscriber::query()
            ->where('status', 'subscribed')
            ->orderBy('id')
            ->get();

        $sent = 0;
        foreach ($subscribers as $subscriber) {
            if (!$subscriber->unsubscribe_token) {
                $subscriber->unsubscribe_token = bin2hex(random_bytes(24));
            }
            $unsubscribeUrl = $baseUrl . '/api/newsletter/unsubscribe?token=' . urlencode($subscriber->unsubscribe_token);
            $variables = [
                '{platform_name}' => $platformName ?: 'Alumni Global',
                '{unsubscribe_url}' => $unsubscribeUrl,
            ];
            $finalBody = str_replace(array_keys($variables), array_values($variables), $body);
            if (strpos($finalBody, $unsubscribeUrl) === false) {
                $finalBody .= "\n\nUnsubscribe: {$unsubscribeUrl}";
            }
            Mail::html(nl2br(e($finalBody)), function ($message) use ($subscriber, $subject) {
                $message->to($subscriber->email)->subject($subject);
            });
            $subscriber->last_sent_at = now();
            $subscriber->save();
            $sent++;
        }

        SystemSetting::updateOrCreate(
            ['key' => 'newsletter_launch_sent_at'],
            ['value' => now(), 'updated_by' => null]
        );

        return $sent;
    }
}
