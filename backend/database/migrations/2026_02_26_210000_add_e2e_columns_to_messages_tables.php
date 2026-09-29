<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('direct_messages', function (Blueprint $table) {
            $table->boolean('is_encrypted')->default(false)->after('body');
            $table->longText('encrypted_payload')->nullable()->after('is_encrypted');
            $table->string('encryption_version', 30)->nullable()->after('encrypted_payload');
            $table->string('encrypted_nonce', 255)->nullable()->after('encryption_version');
            $table->string('sender_key_id', 255)->nullable()->after('encrypted_nonce');
        });

        Schema::table('group_chat_messages', function (Blueprint $table) {
            $table->boolean('is_encrypted')->default(false)->after('body');
            $table->longText('encrypted_payload')->nullable()->after('is_encrypted');
            $table->string('encryption_version', 30)->nullable()->after('encrypted_payload');
            $table->string('encrypted_nonce', 255)->nullable()->after('encryption_version');
            $table->string('sender_key_id', 255)->nullable()->after('encrypted_nonce');
        });
    }

    public function down(): void
    {
        Schema::table('direct_messages', function (Blueprint $table) {
            $table->dropColumn([
                'is_encrypted',
                'encrypted_payload',
                'encryption_version',
                'encrypted_nonce',
                'sender_key_id',
            ]);
        });

        Schema::table('group_chat_messages', function (Blueprint $table) {
            $table->dropColumn([
                'is_encrypted',
                'encrypted_payload',
                'encryption_version',
                'encrypted_nonce',
                'sender_key_id',
            ]);
        });
    }
};
