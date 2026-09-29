<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\DonationCampaignStoreRequest;
use App\Http\Requests\Api\DonationCampaignUpdateRequest;
use App\Http\Requests\Api\DonationCreateRequest;
use App\Http\Resources\Api\DonationCampaignResource;
use App\Http\Resources\Api\DonationResource;
use App\Http\Resources\Api\PaymentTransactionResource;
use App\Models\Donation;
use App\Models\DonationCampaign;
use App\Models\InstitutionPaymentSetting;
use App\Models\PaymentTransaction;
use App\Models\SystemSetting;
use App\Services\Payments\PaymentGateway;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class DonationCampaignController extends Controller
{
    public function index(Request $request)
    {
        $actor = $request->user();
        $query = DonationCampaign::query()
            ->with(['institution.paymentSetting', 'creator:id,name,email,institution_id'])
            ->latest();

        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            $query->where('is_active', true);
        } elseif ($request->filled('status')) {
            $query->where('is_active', $request->query('status') === 'active');
        }

        if ($request->filled('institution_id')) {
            $query->where('institution_id', (int) $request->query('institution_id'));
        }

        return $this->paginatedResponse($query->paginate((int) $request->query('per_page', 20)), DonationCampaignResource::class);
    }

    public function store(DonationCampaignStoreRequest $request)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $data = $request->validated();
        $institutionId = $data['institution_id'] ?? $actor->institution_id;

        if ($actor->role === 'institution_admin' && $institutionId && (int) $institutionId !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $campaign = DonationCampaign::create([
            'institution_id' => $institutionId,
            'created_by' => $actor->id,
            'title' => $data['title'],
            'description' => $data['description'] ?? null,
            'image_url' => $data['image_url'] ?? null,
            'target_amount' => $data['target_amount'],
            'currency' => strtoupper($data['currency']),
            'starts_at' => $data['starts_at'] ?? null,
            'ends_at' => $data['ends_at'] ?? null,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json([
            'message' => 'Campaign created',
            'campaign' => new DonationCampaignResource($campaign->load(['institution', 'creator:id,name,email,institution_id'])),
        ], 201);
    }

    public function show(DonationCampaign $campaign)
    {
        $campaign->load(['institution.paymentSetting', 'creator:id,name,email,institution_id']);

        return response()->json([
            'campaign' => new DonationCampaignResource($campaign),
        ]);
    }

    public function update(DonationCampaignUpdateRequest $request, DonationCampaign $campaign)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $campaign->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $data = $request->validated();
        if ($actor->role === 'institution_admin' && isset($data['institution_id']) && (int) $data['institution_id'] !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        if (isset($data['currency'])) {
            $data['currency'] = strtoupper($data['currency']);
        }

        $campaign->update($data);

        return response()->json([
            'message' => 'Campaign updated',
            'campaign' => new DonationCampaignResource($campaign->fresh()->load(['institution', 'creator:id,name,email,institution_id'])),
        ]);
    }

    public function destroy(Request $request, DonationCampaign $campaign)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $campaign->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $campaign->update(['is_active' => false]);

        return response()->json(['message' => 'Campaign deactivated']);
    }

    public function forceDestroy(Request $request, DonationCampaign $campaign)
    {
        $actor = $request->user();
        if ($actor->role !== 'super_admin') {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        $campaign->delete();

        return response()->json(['message' => 'Campaign deleted']);
    }

    public function donate(DonationCreateRequest $request, DonationCampaign $campaign)
    {
        $user = $request->user();
        $data = $request->validated();
        $provider = strtolower($data['provider']);

        $settings = InstitutionPaymentSetting::where('institution_id', $campaign->institution_id)->first();
        if (!$settings || !$settings->hasProvider($provider)) {
            return response()->json([
                'message' => 'Payment provider not configured for this institution.',
            ], 422);
        }

        $feeEnabledRaw = SystemSetting::query()->where('key', 'platform_fee_enabled')->value('value');
        $feeEnabled = is_bool($feeEnabledRaw) ? $feeEnabledRaw : (is_numeric($feeEnabledRaw) ? (bool) $feeEnabledRaw : true);
        $feePercentRaw = SystemSetting::query()->where('key', 'platform_fee_percent')->value('value');
        if (is_array($feePercentRaw)) {
            $feePercentRaw = $feePercentRaw['value'] ?? null;
        }
        $feePercent = $feeEnabled && is_numeric($feePercentRaw) ? (float) $feePercentRaw : 0.0;
        $feeAmount = round(((float) $data['amount']) * ($feePercent / 100), 2);
        $netAmount = max(0, (float) $data['amount'] - $feeAmount);

        $result = DB::transaction(function () use ($user, $data, $campaign, $feePercent, $feeAmount, $netAmount) {
            $transaction = PaymentTransaction::create([
                'user_id' => $user->id,
                'institution_id' => $campaign->institution_id,
                'type' => 'donation',
                'provider' => $data['provider'],
                'status' => 'pending',
                'amount' => $data['amount'],
                'currency' => strtoupper($data['currency']),
                'reference' => 'TXN-' . Str::upper(Str::random(12)),
                'provider_reference' => 'PROV-' . Str::upper(Str::random(10)),
                'metadata' => [
                    'campaign_id' => $campaign->id,
                    'platform_fee_percent' => $feePercent,
                    'platform_fee_amount' => $feeAmount,
                    'net_amount' => $netAmount,
                ],
                'paid_at' => null,
                'receipt_url' => null,
            ]);

            if ($feeAmount > 0) {
                PaymentTransaction::create([
                    'user_id' => $user->id,
                    'institution_id' => null,
                    'type' => 'platform_fee',
                    'provider' => $data['provider'],
                    'status' => 'pending',
                    'amount' => $feeAmount,
                    'currency' => strtoupper($data['currency']),
                    'reference' => 'PLT-' . Str::upper(Str::random(10)),
                    'provider_reference' => 'PROV-FEE-' . Str::upper(Str::random(8)),
                    'metadata' => [
                        'campaign_id' => $campaign->id,
                        'donation_transaction_id' => $transaction->id,
                        'platform_fee_percent' => $feePercent,
                    ],
                    'paid_at' => null,
                ]);
            }

            $donation = Donation::create([
                'campaign_id' => $campaign->id,
                'user_id' => $user->id,
                'transaction_id' => $transaction->id,
                'amount' => $data['amount'],
                'currency' => strtoupper($data['currency']),
                'is_anonymous' => (bool) ($data['is_anonymous'] ?? false),
                'status' => 'pending',
                'message' => $data['message'] ?? null,
            ]);

            return [$transaction, $donation];
        });

        [$transaction, $donation] = $result;
        $returnUrl = rtrim(config('app.url'), '/') . '/payments/return?provider=' . strtolower($data['provider']) . '&reference=' . $transaction->reference;
        $gateway = PaymentGateway::initiate(strtolower($data['provider']), $settings, [
            'amount' => $data['amount'],
            'currency' => strtoupper($data['currency']),
            'reference' => $transaction->reference,
            'email' => $user->email,
            'customer_name' => $user->name,
            'title' => $campaign->title,
            'description' => $campaign->description ?? 'Donation',
            'return_url' => $returnUrl,
            'metadata' => [
                'campaign_id' => $campaign->id,
                'donation_id' => $donation->id,
                'transaction_id' => $transaction->id,
            ],
            'paypal_mode' => config('services.paypal.mode', 'live'),
        ]);

        if (!($gateway['ok'] ?? false)) {
            $transaction->update([
                'status' => 'failed',
                'metadata' => array_merge($transaction->metadata ?? [], ['gateway_error' => $gateway['message'] ?? 'init_failed']),
            ]);
            return response()->json([
                'message' => $gateway['message'] ?? 'Payment initialization failed',
            ], 422);
        }

        $transaction->update([
            'provider_reference' => $gateway['provider_reference'] ?? $transaction->provider_reference,
            'metadata' => array_merge($transaction->metadata ?? [], [
                'checkout_url' => $gateway['checkout_url'] ?? null,
                'gateway_raw' => $gateway['raw'] ?? null,
            ]),
        ]);

        return response()->json([
            'message' => 'Donation initiated',
            'transaction' => new PaymentTransactionResource($transaction),
            'donation' => new DonationResource($donation->load(['campaign.institution', 'campaign.creator:id,name,email,institution_id', 'transaction'])),
            'checkout_url' => $gateway['checkout_url'] ?? null,
        ], 201);
    }

    public function report(DonationCampaign $campaign)
    {
        $campaign->load(['institution.paymentSetting', 'creator:id,name,email,institution_id']);
        $donations = Donation::query()->where('campaign_id', $campaign->id)->where('status', 'success');
        $feeEnabledRaw = SystemSetting::query()->where('key', 'platform_fee_enabled')->value('value');
        $feeEnabled = is_bool($feeEnabledRaw) ? $feeEnabledRaw : (is_numeric($feeEnabledRaw) ? (bool) $feeEnabledRaw : true);
        $feePercentRaw = SystemSetting::query()->where('key', 'platform_fee_percent')->value('value');
        if (is_array($feePercentRaw)) {
            $feePercentRaw = $feePercentRaw['value'] ?? null;
        }
        $feePercent = $feeEnabled && is_numeric($feePercentRaw) ? (float) $feePercentRaw : 0.0;

        $totalRaised = (float) $donations->sum('amount');
        return response()->json([
            'campaign' => new DonationCampaignResource($campaign),
            'stats' => [
                'total_donations' => $donations->count(),
                'total_raised' => $totalRaised,
                'average_donation' => (float) $donations->avg('amount'),
                'top_donation' => (float) $donations->max('amount'),
                'platform_fee_percent' => $feePercent,
                'platform_fee_total' => $totalRaised * ($feePercent / 100),
            ],
        ]);
    }

    public function donations(Request $request, DonationCampaign $campaign)
    {
        $actor = $request->user();
        if (!in_array($actor->role, ['institution_admin', 'super_admin'], true)) {
            return response()->json(['message' => 'Not authorized'], 403);
        }

        if ($actor->role === 'institution_admin' && (int) $campaign->institution_id !== (int) $actor->institution_id) {
            return response()->json(['message' => 'Not authorized for this institution'], 403);
        }

        $donations = Donation::query()
            ->with(['user:id,name,email', 'transaction'])
            ->where('campaign_id', $campaign->id)
            ->where('status', 'success')
            ->latest()
            ->paginate((int) $request->query('per_page', 50));

        return $this->paginatedResponse($donations, DonationResource::class);
    }
}
