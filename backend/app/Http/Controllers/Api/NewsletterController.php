<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\NewsletterSubscriber;
use App\Models\SystemSetting;
use App\Services\NewsletterService;
use Illuminate\Http\Request;

class NewsletterController extends Controller
{
    public function subscribe(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:190'],
            'source' => ['nullable', 'string', 'max:120'],
        ]);

        $subscriber = NewsletterSubscriber::query()->where('email', $data['email'])->first();
        if (!$subscriber) {
            $subscriber = NewsletterSubscriber::create([
                'email' => $data['email'],
                'status' => 'subscribed',
                'source' => $data['source'] ?? null,
                'ip_address' => $request->ip(),
                'user_agent' => substr((string) $request->userAgent(), 0, 255),
                'subscribed_at' => now(),
                'unsubscribe_token' => bin2hex(random_bytes(24)),
            ]);
        } else {
            $subscriber->status = 'subscribed';
            $subscriber->source = $subscriber->source ?: ($data['source'] ?? null);
            $subscriber->subscribed_at = $subscriber->subscribed_at ?: now();
            if (!$subscriber->unsubscribe_token) {
                $subscriber->unsubscribe_token = bin2hex(random_bytes(24));
            }
            $subscriber->save();
        }

        return response()->json([
            'message' => 'Subscribed',
            'subscriber_id' => $subscriber->id,
        ]);
    }

    public function index(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $query = NewsletterSubscriber::query()->orderByDesc('subscribed_at');
        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }
        if ($request->filled('q')) {
            $q = $request->query('q');
            $query->where('email', 'like', '%' . $q . '%');
        }

        $rows = $query->paginate((int) $request->query('per_page', 25));

        return $this->paginatedResponse($rows, null);
    }

    public function sendLaunch(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'subject' => ['nullable', 'string', 'max:200'],
            'body' => ['nullable', 'string', 'max:5000'],
        ]);

        $service = app(NewsletterService::class);
        $sent = $service->sendLaunch($data['subject'] ?? null, $data['body'] ?? null);

        return response()->json([
            'message' => 'Newsletter launch sent',
            'sent' => $sent,
        ]);
    }

    public function unsubscribe(Request $request)
    {
        $token = $request->query('token');
        if (!$token) {
            return response()->json(['message' => 'Invalid token'], 422);
        }
        $subscriber = NewsletterSubscriber::query()->where('unsubscribe_token', $token)->first();
        if (!$subscriber) {
            return response()->json(['message' => 'Subscriber not found'], 404);
        }
        $subscriber->status = 'unsubscribed';
        $subscriber->unsubscribed_at = now();
        $subscriber->save();

        return response()->json(['message' => 'You have been unsubscribed']);
    }

    public function export(Request $request)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $rows = NewsletterSubscriber::query()
            ->orderByDesc('subscribed_at')
            ->get(['email', 'status', 'source', 'subscribed_at', 'last_sent_at', 'unsubscribed_at']);

        $header = ['email', 'status', 'source', 'subscribed_at', 'last_sent_at', 'unsubscribed_at'];
        $lines = [];
        $lines[] = implode(',', $header);
        foreach ($rows as $row) {
            $line = [
                $row->email,
                $row->status,
                $row->source,
                optional($row->subscribed_at)->toIso8601String(),
                optional($row->last_sent_at)->toIso8601String(),
                optional($row->unsubscribed_at)->toIso8601String(),
            ];
            $lines[] = implode(',', array_map(function ($value) {
                $value = (string) ($value ?? '');
                $value = str_replace('"', '""', $value);
                return '"' . $value . '"';
            }, $line));
        }

        $csv = implode("\n", $lines);
        return response($csv, 200, [
            'Content-Type' => 'text/csv',
            'Content-Disposition' => 'attachment; filename="newsletter-subscribers.csv"',
        ]);
    }
}
