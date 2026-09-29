<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\PaymentTransactionResource;
use App\Http\Resources\Api\SubscriptionResource;
use App\Models\AuditLog;
use App\Models\PaymentTransaction;
use App\Models\Subscription;
use App\Models\SystemSetting;
use App\Services\ReceiptService;
use Illuminate\Http\Request;

class AdminPaymentController extends Controller
{
    public function transactions(Request $request)
    {
        $actor = $request->user();
        if (!$this->hasPermission($actor, 'view_transactions')) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $query = PaymentTransaction::query()
            ->with(['user:id,name,email,institution_id', 'institution:id,name,slug,status'])
            ->latest();

        if ($actor->role === 'institution_admin') {
            $query->where('institution_id', $actor->institution_id);
        } elseif ($request->filled('institution_id')) {
            $query->where('institution_id', $request->query('institution_id'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }

        if ($request->filled('type')) {
            $query->where('type', $request->query('type'));
        }

        if ($request->filled('provider')) {
            $query->where('provider', $request->query('provider'));
        }

        if ($request->filled('currency')) {
            $query->where('currency', strtoupper($request->query('currency')));
        }

        if ($request->filled('search')) {
            $search = $request->query('search');
            $query->where(function ($q) use ($search) {
                $q->where('reference', 'like', '%' . $search . '%')
                    ->orWhere('provider_reference', 'like', '%' . $search . '%');
            });
        }

        if ($request->filled('from')) {
            $query->whereDate('created_at', '>=', $request->query('from'));
        }

        if ($request->filled('to')) {
            $query->whereDate('created_at', '<=', $request->query('to'));
        }

        $transactions = $query->paginate((int) $request->query('per_page', 30));

        return $this->paginatedResponse($transactions, PaymentTransactionResource::class);
    }

    public function subscriptions(Request $request)
    {
        $actor = $request->user();
        if (!$this->hasPermission($actor, 'view_subscriptions')) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $query = Subscription::query()
            ->with(['user:id,name,email,institution_id', 'institution:id,name,slug,status'])
            ->latest();

        if ($actor->role === 'institution_admin') {
            $query->where('institution_id', $actor->institution_id);
        } elseif ($request->filled('institution_id')) {
            $query->where('institution_id', $request->query('institution_id'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->query('status'));
        }

        if ($request->filled('interval')) {
            $query->where('interval', $request->query('interval'));
        }

        if ($request->filled('provider')) {
            $query->where('provider', $request->query('provider'));
        }

        if ($request->filled('search')) {
            $search = $request->query('search');
            $query->where(function ($q) use ($search) {
                $q->where('plan_name', 'like', '%' . $search . '%')
                    ->orWhereHas('user', function ($sub) use ($search) {
                        $sub->where('name', 'like', '%' . $search . '%')
                            ->orWhere('email', 'like', '%' . $search . '%');
                    });
            });
        }

        $subscriptions = $query->paginate((int) $request->query('per_page', 30));

        return $this->paginatedResponse($subscriptions, SubscriptionResource::class);
    }

    public function generateReceipt(Request $request, PaymentTransaction $transaction)
    {
        $actor = $request->user();
        if (!$this->hasPermission($actor, 'manage_receipts')) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $transaction->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if (!$transaction->provider_reference) {
            return response()->json(['message' => 'Missing provider reference'], 422);
        }

        if (!in_array((string) $transaction->status, ['success', 'refunded'], true)) {
            return response()->json(['message' => 'Receipts can only be generated for successful or refunded payments'], 422);
        }

        $receiptUrl = app(ReceiptService::class)->generate($transaction);
        if ($receiptUrl) {
            $transaction->update(['receipt_url' => $receiptUrl]);
        }

        return response()->json([
            'message' => 'Receipt generated',
            'transaction' => new PaymentTransactionResource($transaction->fresh(['user', 'institution'])),
        ]);
    }

    public function backfillReceipts(Request $request)
    {
        $actor = $request->user();
        if (!$this->hasPermission($actor, 'manage_receipts')) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validate([
            'force' => ['sometimes', 'boolean'],
            'limit' => ['sometimes', 'integer', 'min:1', 'max:2000'],
        ]);

        $force = (bool) ($data['force'] ?? false);
        $limit = (int) ($data['limit'] ?? 500);
        $service = app(ReceiptService::class);

        $query = PaymentTransaction::query()
            ->whereNotNull('provider_reference')
            ->whereIn('status', ['success', 'refunded']);
        if ($actor->role === 'institution_admin') {
            $query->where('institution_id', $actor->institution_id);
        }
        if (!$force) {
            $query->where(function ($q) {
                $q->whereNull('receipt_url')
                    ->orWhere('receipt_url', 'like', '%receipt.example%');
            });
        }

        $generated = 0;
        $failed = 0;
        $processed = 0;

        $query->orderBy('id')->chunkById(200, function ($transactions) use (&$generated, &$failed, &$processed, $limit, $service) {
            foreach ($transactions as $transaction) {
                if ($processed >= $limit) {
                    return false;
                }
                $url = $service->generate($transaction);
                if ($url) {
                    $transaction->update(['receipt_url' => $url]);
                    $generated++;
                } else {
                    $failed++;
                }
                $processed++;
            }
        });

        return response()->json([
            'message' => 'Receipt backfill complete',
            'generated' => $generated,
            'failed' => $failed,
            'processed' => $processed,
        ]);
    }

    public function cancelSubscription(Request $request, Subscription $subscription)
    {
        $actor = $request->user();
        if (!$this->hasPermission($actor, 'view_subscriptions')) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $subscription->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $subscription->update([
            'status' => 'cancelled',
            'cancelled_at' => now(),
        ]);

        AuditLog::record($actor, 'subscription.cancelled', Subscription::class, $subscription->id, [
            'status' => 'cancelled',
        ], $request);

        return response()->json([
            'message' => 'Subscription cancelled',
            'subscription' => new SubscriptionResource($subscription->fresh(['user', 'institution'])),
        ]);
    }

    private function hasPermission($user, string $permission): bool
    {
        if (!$user) {
            return false;
        }

        if ($user->role === 'super_admin') {
            return true;
        }

        if ($user->role === 'accountant' && in_array($permission, ['view_transactions', 'manage_receipts', 'view_subscriptions'], true)) {
            return true;
        }

        $roleCatalog = SystemSetting::query()->where('key', 'role_catalog')->value('value');
        if (is_array($roleCatalog) && is_array($roleCatalog[$user->role] ?? null)) {
            $permissions = is_array($roleCatalog[$user->role]['permissions'] ?? null)
                ? $roleCatalog[$user->role]['permissions']
                : [];
            if (array_key_exists($permission, $permissions)) {
                return (bool) $permissions[$permission];
            }
        }

        if ($user->role === 'institution_admin') {
            $raw = SystemSetting::query()->where('key', 'admin_permissions')->value('value');
            $permissions = is_array($raw) ? $raw : [];
            return array_key_exists($permission, $permissions) ? (bool) $permissions[$permission] : false;
        }

        return false;
    }
}
