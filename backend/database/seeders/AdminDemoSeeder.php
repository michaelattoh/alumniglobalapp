<?php

namespace Database\Seeders;

use App\Models\Ad;
use App\Models\AuditLog;
use App\Models\Institution;
use App\Models\PaymentTransaction;
use App\Models\Post;
use App\Models\PostReport;
use App\Models\Subscription;
use App\Models\SystemSetting;
use App\Models\SupportTicket;
use App\Models\User;
use App\Models\UserReport;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AdminDemoSeeder extends Seeder
{
    public function run(): void
    {
        $primaryInstitution = Institution::firstOrCreate(
            ['slug' => 'sample-university'],
            ['name' => 'Sample University', 'status' => 'active']
        );

        $secondInstitution = Institution::firstOrCreate(
            ['slug' => 'global-tech-institute'],
            ['name' => 'Global Tech Institute', 'status' => 'active']
        );

        $superAdmin = User::firstOrCreate(
            ['email' => 'superadmin@alumni.app'],
            [
                'name' => 'Super Admin',
                'password' => Hash::make('Password123!'),
                'role' => 'super_admin',
                'status' => 'active',
            ]
        );

        $institutionAdmin = User::firstOrCreate(
            ['email' => 'admin@sample.edu'],
            [
                'name' => 'Institution Admin',
                'password' => Hash::make('Password123!'),
                'role' => 'institution_admin',
                'institution_id' => $primaryInstitution->id,
                'status' => 'active',
            ]
        );

        $alumniA = User::firstOrCreate(
            ['email' => 'alumni.one@example.com'],
            [
                'name' => 'Alumni One',
                'password' => Hash::make('Password123!'),
                'role' => 'alumni',
                'institution_id' => $primaryInstitution->id,
                'status' => 'active',
            ]
        );

        $alumniB = User::firstOrCreate(
            ['email' => 'alumni.two@example.com'],
            [
                'name' => 'Alumni Two',
                'password' => Hash::make('Password123!'),
                'role' => 'alumni',
                'institution_id' => $secondInstitution->id,
                'status' => 'active',
            ]
        );

        $postA = Post::firstOrCreate(
            ['user_id' => $alumniA->id, 'content' => 'Excited about our alumni reunion event!'],
            [
                'institution_id' => $primaryInstitution->id,
                'visibility' => 'institution_only',
            ]
        );

        $postB = Post::firstOrCreate(
            ['user_id' => $alumniB->id, 'content' => 'Looking to connect with alumni in fintech.'],
            [
                'institution_id' => $secondInstitution->id,
                'visibility' => 'public',
            ]
        );

        UserReport::firstOrCreate(
            ['reported_by' => $alumniA->id, 'reported_user_id' => $alumniB->id],
            [
                'status' => 'pending',
                'reason' => 'Spam outreach message',
            ]
        );

        PostReport::firstOrCreate(
            ['post_id' => $postA->id, 'reported_by' => $alumniB->id],
            [
                'status' => 'pending',
                'reason' => 'Off-topic content',
            ]
        );

        $transactions = [
            [
                'reference' => 'TXN-ALUM-1001',
                'type' => 'membership_fee',
                'provider' => 'stripe',
                'status' => 'success',
                'amount' => 49.99,
                'currency' => 'GHS',
                'user_id' => $alumniA->id,
                'institution_id' => $primaryInstitution->id,
                'paid_at' => now()->subDays(3),
            ],
            [
                'reference' => 'TXN-ALUM-1002',
                'type' => 'donation',
                'provider' => 'paystack',
                'status' => 'success',
                'amount' => 120.00,
                'currency' => 'GHS',
                'user_id' => $alumniA->id,
                'institution_id' => $primaryInstitution->id,
                'paid_at' => now()->subDays(1),
            ],
            [
                'reference' => 'TXN-ALUM-1003',
                'type' => 'event_ticket',
                'provider' => 'flutterwave',
                'status' => 'failed',
                'amount' => 15.00,
                'currency' => 'GHS',
                'user_id' => $alumniB->id,
                'institution_id' => $secondInstitution->id,
                'paid_at' => now()->subDays(2),
            ],
        ];

        foreach ($transactions as $txn) {
            PaymentTransaction::firstOrCreate(
                ['reference' => $txn['reference']],
                array_merge($txn, [
                    'provider_reference' => 'PROV-' . Str::upper(Str::random(8)),
                    'receipt_url' => 'https://receipts.example/' . Str::uuid(),
                ])
            );
        }

        $baseTransaction = PaymentTransaction::firstOrCreate(
            ['reference' => 'TXN-ALUM-REFUND-1004'],
            [
                'type' => 'subscription',
                'provider' => 'stripe',
                'status' => 'success',
                'amount' => 9.99,
                'currency' => 'GHS',
                'user_id' => $alumniA->id,
                'institution_id' => $primaryInstitution->id,
                'paid_at' => now()->subDays(5),
                'provider_reference' => 'PROV-' . Str::upper(Str::random(8)),
                'receipt_url' => 'https://receipts.example/' . Str::uuid(),
            ]
        );

        PaymentTransaction::firstOrCreate(
            ['reference' => 'RFD-ALUM-1004'],
            [
                'type' => 'refund',
                'provider' => 'stripe',
                'status' => 'success',
                'amount' => 9.99,
                'currency' => 'GHS',
                'user_id' => $alumniA->id,
                'institution_id' => $primaryInstitution->id,
                'refunded_transaction_id' => $baseTransaction->id,
                'paid_at' => now()->subDays(4),
                'refunded_at' => now()->subDays(4),
                'provider_reference' => 'PROV-' . Str::upper(Str::random(8)),
            ]
        );

        Subscription::firstOrCreate(
            ['provider_reference' => 'SUB-ALUM-1001'],
            [
                'user_id' => $alumniA->id,
                'institution_id' => $primaryInstitution->id,
                'plan_name' => 'Premium Alumni',
                'interval' => 'monthly',
                'amount' => 9.99,
                'currency' => 'GHS',
                'provider' => 'stripe',
                'status' => 'active',
                'starts_at' => now()->subDays(10),
                'ends_at' => now()->addDays(20),
            ]
        );

        Subscription::firstOrCreate(
            ['provider_reference' => 'SUB-ALUM-1002'],
            [
                'user_id' => $alumniB->id,
                'institution_id' => $secondInstitution->id,
                'plan_name' => 'Annual Alumni',
                'interval' => 'yearly',
                'amount' => 99.99,
                'currency' => 'GHS',
                'provider' => 'paystack',
                'status' => 'cancelled',
                'starts_at' => now()->subMonths(3),
                'ends_at' => now()->addMonths(9),
                'cancelled_at' => now()->subDays(5),
            ]
        );

        Ad::firstOrCreate(
            ['title' => 'Alumni Career Fair'],
            [
                'advertiser_id' => $institutionAdmin->id,
                'institution_id' => $primaryInstitution->id,
                'content' => 'Join the career fair this weekend.',
                'placement' => 'feed',
                'pricing_model' => 'cpc',
                'price' => 1.5,
                'budget' => 250,
                'currency' => 'GHS',
                'target_location' => 'Lagos',
                'target_interests' => ['career', 'networking'],
                'status' => 'active',
                'starts_at' => now()->subDay(),
            ]
        );

        Ad::firstOrCreate(
            ['title' => 'MBA Scholarship Drive'],
            [
                'advertiser_id' => $superAdmin->id,
                'institution_id' => $secondInstitution->id,
                'content' => 'Support our scholarship fund.',
                'placement' => 'banner',
                'pricing_model' => 'flat',
                'price' => 500,
                'budget' => 500,
                'currency' => 'GHS',
                'status' => 'paused',
                'starts_at' => now()->subDays(3),
            ]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'maintenance_banner'],
            ['value' => 'Scheduled maintenance Friday at 2:00 AM UTC', 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'app_name'],
            ['value' => 'Alumni Global', 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'primary_color'],
            ['value' => '#2563EB', 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'secondary_color'],
            ['value' => '#0F172A', 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'default_visibility'],
            ['value' => 'public', 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'auto_verify_alumni'],
            ['value' => true, 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'require_join_approval'],
            ['value' => true, 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'platform_fee_percent'],
            ['value' => 5, 'updated_by' => $superAdmin->id]
        );
        SystemSetting::updateOrCreate(
            ['key' => 'platform_fee_enabled'],
            ['value' => true, 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'default_currency'],
            ['value' => 'GHS', 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'ads_enabled'],
            ['value' => true, 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'ai_enabled'],
            ['value' => true, 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'theme_presets'],
            ['value' => [
                ['name' => 'Classic', 'primary' => '#0f172a', 'secondary' => '#2563eb'],
                ['name' => 'Emerald', 'primary' => '#064e3b', 'secondary' => '#10b981'],
            ], 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'feature_flags'],
            ['value' => ['ads', 'ai_feed', 'donations'], 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'email_test_template'],
            [
                'value' => [
                    'subject' => 'Alumni Global: Test Email',
                    'body' => 'This is a test email from Alumni Global Admin.',
                ],
                'updated_by' => $superAdmin->id,
            ]
        );

        SupportTicket::firstOrCreate(
            ['user_id' => $alumniA->id, 'subject' => 'Trouble accessing event tickets'],
            [
                'institution_id' => $primaryInstitution->id,
                'message' => 'I paid for the reunion ticket but it is not showing in my account.',
                'category' => 'billing',
                'priority' => 'high',
                'status' => 'pending',
            ]
        );

        SupportTicket::firstOrCreate(
            ['user_id' => $alumniB->id, 'subject' => 'Can’t update my graduation year'],
            [
                'institution_id' => $secondInstitution->id,
                'message' => 'The profile page keeps resetting my graduation year.',
                'category' => 'account',
                'priority' => 'normal',
                'status' => 'pending',
            ]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'data_retention_days'],
            ['value' => 365, 'updated_by' => $superAdmin->id]
        );

        SystemSetting::updateOrCreate(
            ['key' => 'default_moderation_rules'],
            ['value' => ['no hate speech', 'no harassment', 'no spam'], 'updated_by' => $superAdmin->id]
        );

        AuditLog::firstOrCreate(
            ['action' => 'institution.created', 'entity_id' => $primaryInstitution->id],
            [
                'actor_id' => $superAdmin->id,
                'entity_type' => Institution::class,
                'metadata' => ['status' => 'active'],
            ]
        );

        AuditLog::firstOrCreate(
            ['action' => 'payment.refund', 'entity_id' => $baseTransaction->id],
            [
                'actor_id' => $superAdmin->id,
                'entity_type' => PaymentTransaction::class,
                'metadata' => ['amount' => 9.99],
            ]
        );
    }
}
