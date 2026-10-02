<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Notification Outbox
        Schema::create('notification_outbox', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->string('event_kind', 40);
            $table->uuid('resource_id');
            $table->jsonb('payload');
            $table->integer('attempts')->default(0);
            $table->timestampTz('processed_at')->nullable();
            $table->timestampTz('created_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->index(['processed_at', 'created_at']);
        });

        // 2. Inbox Items
        Schema::create('inbox_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('user_id');
            $table->uuid('event_id');
            $table->jsonb('payload');
            $table->timestampTz('read_at')->nullable();
            $table->integer('version')->default(1);
            $table->timestampTz('updated_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->foreign('event_id')->references('id')->on('notification_outbox')->cascadeOnDelete();
            $table->unique(['event_id', 'user_id']);
            $table->index(['user_id', 'updated_at', 'id']);
        });

        // 3. Push Devices
        Schema::create('push_devices', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('user_id');
            $table->uuid('device_id');
            $table->text('fcm_token_encrypted');
            $table->boolean('enabled')->default(true);
            $table->timestampTz('updated_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['user_id', 'device_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('push_devices');
        Schema::dropIfExists('inbox_items');
        Schema::dropIfExists('notification_outbox');
    }
};
