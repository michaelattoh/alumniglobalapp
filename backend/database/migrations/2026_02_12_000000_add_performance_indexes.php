<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $this->addIndexIfMissing('posts', ['institution_id', 'created_at'], 'posts_institution_created_idx');
        $this->addIndexIfMissing('posts', ['user_id', 'created_at'], 'posts_user_created_idx');

        $this->addIndexIfMissing('stories', ['institution_id', 'created_at'], 'stories_institution_created_idx');
        $this->addIndexIfMissing('stories', ['user_id', 'created_at'], 'stories_user_created_idx');

        $this->addIndexIfMissing('events', ['institution_id', 'starts_at'], 'events_institution_starts_idx');

        $this->addIndexIfMissing('donations', ['campaign_id', 'status'], 'donations_campaign_status_idx');
        $this->addIndexIfMissing('donations', ['user_id', 'created_at'], 'donations_user_created_idx');

        $this->addIndexIfMissing('donation_campaigns', ['institution_id', 'is_active'], 'campaigns_institution_active_idx');
        $this->addIndexIfMissing('donation_campaigns', ['created_at'], 'campaigns_created_idx');

        $this->addIndexIfMissing('payment_transactions', ['institution_id', 'status', 'type'], 'payments_institution_status_type_idx');
        $this->addIndexIfMissing('payment_transactions', ['created_at'], 'payments_created_idx');

        $this->addIndexIfMissing('analytics_events', ['institution_id', 'event_type', 'occurred_at'], 'analytics_institution_event_idx');
        $this->addIndexIfMissing('analytics_events', ['occurred_at'], 'analytics_occurred_idx');
    }

    public function down(): void
    {
        $this->dropIndexIfExists('posts', 'posts_institution_created_idx');
        $this->dropIndexIfExists('posts', 'posts_user_created_idx');
        $this->dropIndexIfExists('stories', 'stories_institution_created_idx');
        $this->dropIndexIfExists('stories', 'stories_user_created_idx');
        $this->dropIndexIfExists('events', 'events_institution_starts_idx');
        $this->dropIndexIfExists('donations', 'donations_campaign_status_idx');
        $this->dropIndexIfExists('donations', 'donations_user_created_idx');
        $this->dropIndexIfExists('donation_campaigns', 'campaigns_institution_active_idx');
        $this->dropIndexIfExists('donation_campaigns', 'campaigns_created_idx');
        $this->dropIndexIfExists('payment_transactions', 'payments_institution_status_type_idx');
        $this->dropIndexIfExists('payment_transactions', 'payments_created_idx');
        $this->dropIndexIfExists('analytics_events', 'analytics_institution_event_idx');
        $this->dropIndexIfExists('analytics_events', 'analytics_occurred_idx');
    }

    private function addIndexIfMissing(string $table, array $columns, string $indexName): void
    {
        if ($this->indexExists($table, $indexName)) {
            return;
        }

        Schema::table($table, function (Blueprint $table) use ($columns, $indexName) {
            $table->index($columns, $indexName);
        });
    }

    private function dropIndexIfExists(string $table, string $indexName): void
    {
        if (!$this->indexExists($table, $indexName)) {
            return;
        }

        Schema::table($table, function (Blueprint $table) use ($indexName) {
            $table->dropIndex($indexName);
        });
    }

    private function indexExists(string $table, string $indexName): bool
    {
        $database = DB::getDatabaseName();
        $rows = DB::select(
            'SELECT 1 FROM information_schema.statistics WHERE table_schema = ? AND table_name = ? AND index_name = ? LIMIT 1',
            [$database, $table, $indexName]
        );
        return !empty($rows);
    }
};
