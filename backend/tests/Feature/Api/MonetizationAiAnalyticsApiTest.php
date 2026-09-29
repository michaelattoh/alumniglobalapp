<?php

namespace Tests\Feature\Api;

use App\Models\Ad;
use App\Models\DonationCampaign;
use App\Models\Institution;
use App\Models\PaymentTransaction;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class MonetizationAiAnalyticsApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_institution_admin_can_create_campaign_and_user_can_donate(): void
    {
        $institution = Institution::create(['name' => 'Donor U', 'slug' => 'donor-u', 'status' => 'active']);
        $admin = User::factory()->create(['role' => 'institution_admin', 'institution_id' => $institution->id]);
        $alumni = User::factory()->create(['role' => 'alumni', 'institution_id' => $institution->id]);

        $create = $this->actingAs($admin, 'sanctum')->postJson('/api/donation-campaigns', [
            'title' => 'Library Fund',
            'description' => 'Raise for books',
            'target_amount' => 1000,
            'currency' => 'USD',
            'institution_id' => $institution->id,
        ]);

        $create->assertCreated()->assertJsonPath('campaign.title', 'Library Fund');
        $campaignId = $create->json('campaign.id');

        $donate = $this->actingAs($alumni, 'sanctum')->postJson('/api/donation-campaigns/' . $campaignId . '/donate', [
            'provider' => 'stripe',
            'amount' => 150,
            'currency' => 'USD',
            'is_anonymous' => false,
        ]);

        $donate->assertCreated()
            ->assertJsonPath('donation.amount', '150.00')
            ->assertJsonPath('transaction.type', 'donation');

        $campaign = DonationCampaign::findOrFail($campaignId);
        $this->assertSame('150.00', (string) $campaign->raised_amount);
    }

    public function test_payment_history_and_refund_flow(): void
    {
        $superAdmin = User::factory()->create(['role' => 'super_admin']);
        $user = User::factory()->create(['role' => 'alumni']);

        $init = $this->actingAs($user, 'sanctum')->postJson('/api/payments/initiate', [
            'type' => 'membership_fee',
            'provider' => 'paystack',
            'amount' => 50,
            'currency' => 'USD',
        ]);

        $init->assertCreated()->assertJsonPath('transaction.status', 'success');
        $transactionId = $init->json('transaction.id');

        $this->actingAs($user, 'sanctum')->getJson('/api/payments/history')
            ->assertOk()
            ->assertJsonPath('meta.total', 1);

        $this->actingAs($superAdmin, 'sanctum')->postJson('/api/payments/' . $transactionId . '/refund', [
            'reason' => 'duplicate',
        ])->assertOk()->assertJsonPath('transaction.type', 'refund');

        $this->assertDatabaseHas('payment_transactions', [
            'id' => $transactionId,
            'status' => 'refunded',
        ]);
    }

    public function test_ads_serving_click_and_analytics(): void
    {
        $institution = Institution::create(['name' => 'Ads U', 'slug' => 'ads-u', 'status' => 'active']);
        $advertiser = User::factory()->create(['role' => 'institution_admin', 'institution_id' => $institution->id]);
        $viewer = User::factory()->create(['role' => 'alumni', 'institution_id' => $institution->id]);

        $create = $this->actingAs($advertiser, 'sanctum')->postJson('/api/ads', [
            'title' => 'Career fair sponsor',
            'placement' => 'feed',
            'pricing_model' => 'cpc',
            'price' => 1.5,
            'budget' => 100,
            'currency' => 'USD',
            'target_institution_id' => $institution->id,
        ]);

        $create->assertCreated();
        $adId = $create->json('ad.id');

        $serve = $this->actingAs($viewer, 'sanctum')->postJson('/api/ads/serve', [
            'placement' => 'feed',
            'institution_id' => $institution->id,
        ]);
        $serve->assertOk()->assertJsonPath('data.id', $adId);

        $this->actingAs($viewer, 'sanctum')->postJson('/api/ads/' . $adId . '/click')->assertOk();

        $analytics = $this->actingAs($viewer, 'sanctum')->getJson('/api/ads/' . $adId . '/analytics');
        $analytics->assertOk()
            ->assertJsonPath('stats.impressions', 1)
            ->assertJsonPath('stats.clicks', 1);
    }

    public function test_recommendations_ai_controls_analytics_and_dashboards(): void
    {
        $institution = Institution::create(['name' => 'AI U', 'slug' => 'ai-u', 'status' => 'active']);
        $superAdmin = User::factory()->create(['role' => 'super_admin']);
        $institutionAdmin = User::factory()->create(['role' => 'institution_admin', 'institution_id' => $institution->id]);
        $user = User::factory()->create(['role' => 'alumni', 'institution_id' => $institution->id]);

        Post::create([
            'user_id' => $user->id,
            'institution_id' => $institution->id,
            'content' => 'Recommended content',
            'visibility' => 'public',
            'engagement_score' => 10,
            'ai_rank_score' => 15,
        ]);

        $recs = $this->actingAs($user, 'sanctum')->getJson('/api/recommendations?type=content');
        $recs->assertOk()->assertJsonPath('meta.total', 1);
        $recId = $recs->json('data.0.id');

        $this->actingAs($user, 'sanctum')->postJson('/api/recommendations/' . $recId . '/feedback', [
            'action' => 'clicked',
        ])->assertOk();

        $this->actingAs($superAdmin, 'sanctum')->patchJson('/api/ai/controls', [
            'max_daily_recommendations' => 250,
            'recommendations_enabled' => true,
        ])->assertOk()->assertJsonPath('data.max_daily_recommendations', 250);

        PaymentTransaction::create([
            'user_id' => $user->id,
            'institution_id' => $institution->id,
            'type' => 'membership_fee',
            'provider' => 'stripe',
            'status' => 'success',
            'amount' => 25,
            'currency' => 'USD',
            'reference' => 'TXN-ANL-1',
            'provider_reference' => 'P-1',
            'paid_at' => now(),
        ]);

        $this->actingAs($user, 'sanctum')->postJson('/api/analytics/track', [
            'event_type' => 'post_view',
            'entity_type' => 'post',
            'entity_id' => 1,
            'institution_id' => $institution->id,
        ])->assertCreated();

        $this->actingAs($institutionAdmin, 'sanctum')->getJson('/api/analytics/institutions/' . $institution->id)
            ->assertOk()
            ->assertJsonPath('metrics.users_total', 2);

        $this->actingAs($superAdmin, 'sanctum')->getJson('/api/analytics/platform')
            ->assertOk()
            ->assertJsonPath('metrics.revenue_total', 25);

        $this->actingAs($institutionAdmin, 'sanctum')->getJson('/api/dashboard/institution')
            ->assertOk()
            ->assertJsonPath('kpis.members', 2);

        $this->actingAs($superAdmin, 'sanctum')->getJson('/api/dashboard/super')
            ->assertOk()
            ->assertJsonPath('kpis.transactions', 1);
    }
}
