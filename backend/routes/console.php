<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Console\Scheduling\Schedule;
use App\Models\PaymentTransaction;
use App\Models\EventRsvp;
use App\Services\ReceiptService;
use App\Models\Post;
use App\Models\ScheduledNotificationBroadcast;
use App\Models\User;
use App\Services\NotificationService;
use App\Services\FirebaseTopicMessagingService;
use App\Services\NewsletterService;
use App\Models\SystemSetting;
use Illuminate\Support\Facades\Mail;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('receipts:backfill {--all : Regenerate receipts even if they already exist} {--chunk=200}', function () {
    $regenerateAll = (bool) $this->option('all');
    $chunk = max(1, (int) $this->option('chunk'));
    $service = app(ReceiptService::class);

    $query = PaymentTransaction::query()->whereNotNull('provider_reference');
    if (!$regenerateAll) {
        $query->where(function ($q) {
            $q->whereNull('receipt_url')
                ->orWhere('receipt_url', 'like', '%receipt.example%');
        });
    }

    $total = $query->count();
    if ($total === 0) {
        $this->info('No transactions eligible for receipt backfill.');
        return;
    }

    $generated = 0;
    $failed = 0;
    $this->info("Generating receipts for {$total} transactions...");

    $query->orderBy('id')->chunkById($chunk, function ($transactions) use (&$generated, &$failed, $service) {
        foreach ($transactions as $transaction) {
            $url = $service->generate($transaction);
            if ($url) {
                $transaction->update(['receipt_url' => $url]);
                $generated++;
            } else {
                $failed++;
            }
        }
    });

    $this->info("Receipts generated: {$generated}. Failed: {$failed}.");
})->purpose('Generate missing receipts for existing transactions');

Artisan::command('posts:publish-scheduled', function () {
    $now = now();
    $notifications = app(NotificationService::class);

    $due = Post::query()
        ->whereNotNull('scheduled_at')
        ->where('scheduled_at', '<=', $now)
        ->whereNull('scheduled_notified_at')
        ->get();

    if ($due->isEmpty()) {
        $this->info('No scheduled posts due.');
        return;
    }

    foreach ($due as $post) {
        $post->update([
            'scheduled_at' => null,
            'scheduled_notified_at' => $now,
            'created_at' => $now,
        ]);

        $notifications->notify(
            $post->user_id,
            'post',
            'Post published',
            'Your scheduled post is now live.',
            ['post_id' => $post->id]
        );
    }

    $this->info('Published scheduled posts: ' . $due->count());
})->purpose('Publish scheduled posts and notify owners');

app(Schedule::class)
    ->command('posts:publish-scheduled')
    ->everyMinute()
    ->runInBackground();

Artisan::command('newsletter:send-launch', function () {
    $launchAt = SystemSetting::query()->where('key', 'newsletter_launch_date')->value('value');
    $alreadySent = SystemSetting::query()->where('key', 'newsletter_launch_sent_at')->value('value');
    if ($alreadySent) {
        $this->info('Launch newsletter already sent.');
        return;
    }
    if (!$launchAt) {
        $this->info('No launch date set.');
        return;
    }
    $launchTime = \Illuminate\Support\Carbon::parse($launchAt);
    if (now()->lt($launchTime)) {
        $this->info('Launch date not reached yet.');
        return;
    }

    $sent = app(NewsletterService::class)->sendLaunch();
    $this->info("Launch newsletter sent to {$sent} subscribers.");
})->purpose('Send launch newsletter when launch date is reached');

app(Schedule::class)
    ->command('newsletter:send-launch')
    ->hourly()
    ->runInBackground();

Artisan::command('notifications:send-scheduled-broadcasts', function () {
    $firebase = app(FirebaseTopicMessagingService::class);
    $notifications = app(NotificationService::class);
    $due = ScheduledNotificationBroadcast::query()
        ->where('status', 'pending')
        ->where('scheduled_for', '<=', now())
        ->orderBy('scheduled_for')
        ->get();

    if ($due->isEmpty()) {
        $this->info('No scheduled broadcasts due.');
        return;
    }

    foreach ($due as $broadcast) {
        try {
            $firebase->sendToTopic(
                $broadcast->topic,
                $broadcast->title,
                $broadcast->body,
                $broadcast->data ?? [],
            );

            $inAppCount = 0;
            if ($broadcast->create_in_app) {
                $query = User::query()->select(['id', 'role']);
                match ($broadcast->topic) {
                    'alumni' => $query->where('role', 'alumni'),
                    'school_admin' => $query->where('role', 'institution_admin'),
                    'super_admin' => $query->where('role', 'super_admin'),
                    default => null,
                };

                foreach ($query->cursor() as $user) {
                    $notification = $notifications->notifyInAppOnly(
                        $user->id,
                        $broadcast->type ?? 'broadcast',
                        $broadcast->title,
                        $broadcast->body,
                        array_merge($broadcast->data ?? [], [
                            'topic' => $broadcast->topic,
                            'source' => 'scheduled_firebase_broadcast',
                        ]),
                    );

                    if ($notification) {
                        $inAppCount++;
                    }
                }
            }

            $broadcast->update([
                'status' => 'sent',
                'sent_at' => now(),
                'error_message' => null,
            ]);

            $this->info("Sent scheduled broadcast {$broadcast->id} ({$inAppCount} in-app).");
        } catch (\Throwable $e) {
            report($e);
            $broadcast->update([
                'status' => 'failed',
                'error_message' => $e->getMessage(),
            ]);
            $this->error("Failed scheduled broadcast {$broadcast->id}: {$e->getMessage()}");
        }
    }
})->purpose('Send scheduled super-admin notification broadcasts');

app(Schedule::class)
    ->command('notifications:send-scheduled-broadcasts')
    ->everyMinute()
    ->runInBackground();

Artisan::command('events:send-reminders', function () {
    $notifications = app(NotificationService::class);

    $due = EventRsvp::query()
        ->with([
            'user.notificationPreference',
            'event.institution.emailSetting',
        ])
        ->where('status', 'going')
        ->where('reminder_enabled', true)
        ->whereNull('reminder_sent_at')
        ->whereNotNull('reminder_at')
        ->where('reminder_at', '<=', now())
        ->whereHas('event', function ($query) {
            $query->where('is_active', true)
                ->where('starts_at', '>=', now());
        })
        ->orderBy('reminder_at')
        ->limit(200)
        ->get();

    if ($due->isEmpty()) {
        $this->info('No event reminders due.');
        return;
    }

    $sent = 0;

    foreach ($due as $rsvp) {
        $event = $rsvp->event;
        $user = $rsvp->user;
        if (!$event || !$user) {
            $rsvp->update(['reminder_sent_at' => now()]);
            continue;
        }

        $startsAt = optional($event->starts_at)?->timezone(config('app.timezone'));
        $body = $startsAt
            ? 'Reminder: ' . $event->title . ' starts at ' . $startsAt->format('D, M j • H:i') . '.'
            : 'Reminder: ' . $event->title . ' is coming up soon.';

        $notifications->notify(
            (int) $user->id,
            'event_reminder',
            'Event reminder',
            $body,
            [
                'screen' => 'events',
                'event_id' => (string) $event->id,
                'rsvp_status' => $rsvp->status,
            ],
        );

        if ($user->email) {
            try {
                $fromName = null;
                $fromEmail = null;
                $emailSetting = optional($event->institution)->emailSetting;
                if ($emailSetting && $emailSetting->is_enabled && $emailSetting->sender_email) {
                    $fromName = $emailSetting->sender_name;
                    $fromEmail = $emailSetting->sender_email;
                }

                Mail::raw($body, function ($message) use ($user, $event, $fromName, $fromEmail) {
                    if ($fromEmail) {
                        $message->from($fromEmail, $fromName ?: null);
                        $message->replyTo($fromEmail, $fromName ?: null);
                    }
                    $message->to($user->email)->subject('Event reminder: ' . $event->title);
                });
            } catch (\Throwable $e) {
                report($e);
            }
        }

        $rsvp->update(['reminder_sent_at' => now()]);
        $sent++;
    }

    $this->info("Event reminders sent: {$sent}.");
})->purpose('Send reminder notifications and emails for upcoming RSVP events');

app(Schedule::class)
    ->command('events:send-reminders')
    ->everyMinute()
    ->runInBackground();
