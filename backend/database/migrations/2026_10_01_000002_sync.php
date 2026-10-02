<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Idempotency Receipts
        Schema::create('idempotency_receipts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('actor_id');
            $table->uuid('operation_id');
            $table->string('request_hash', 64);
            $table->string('method', 10);
            $table->text('path');
            $table->jsonb('ack');
            $table->timestampTz('accepted_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('actor_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['farm_id', 'actor_id', 'operation_id']);
        });

        // 2. Sync Changes
        Schema::create('sync_changes', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->bigInteger('sequence');
            $table->string('resource_type', 40);
            $table->uuid('resource_id');
            $table->string('action', 20); // upsert, remove
            $table->jsonb('snapshot')->nullable();
            $table->timestampTz('accepted_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->unique(['farm_id', 'sequence']);
            $table->index(['farm_id', 'sequence']);
        });

        // 3. Sync Counters
        Schema::create('sync_counters', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id')->unique();
            $table->bigInteger('last_sequence')->default(0);

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
        });

        // 4. Audit Events
        Schema::create('audit_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('actor_id')->nullable();
            $table->string('action', 80);
            $table->string('resource_type', 40);
            $table->uuid('resource_id');
            $table->jsonb('metadata');
            $table->timestampTz('accepted_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('actor_id')->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_events');
        Schema::dropIfExists('sync_counters');
        Schema::dropIfExists('sync_changes');
        Schema::dropIfExists('idempotency_receipts');
    }
};
