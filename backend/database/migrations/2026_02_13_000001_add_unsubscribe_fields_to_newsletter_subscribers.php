<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('newsletter_subscribers', function (Blueprint $table) {
            if (!Schema::hasColumn('newsletter_subscribers', 'unsubscribe_token')) {
                $table->string('unsubscribe_token', 80)->nullable()->unique()->after('email');
            }
            if (!Schema::hasColumn('newsletter_subscribers', 'unsubscribed_at')) {
                $table->timestamp('unsubscribed_at')->nullable()->after('last_sent_at');
            }
        });
    }

    public function down(): void
    {
        Schema::table('newsletter_subscribers', function (Blueprint $table) {
            if (Schema::hasColumn('newsletter_subscribers', 'unsubscribe_token')) {
                $table->dropColumn('unsubscribe_token');
            }
            if (Schema::hasColumn('newsletter_subscribers', 'unsubscribed_at')) {
                $table->dropColumn('unsubscribed_at');
            }
        });
    }
};
