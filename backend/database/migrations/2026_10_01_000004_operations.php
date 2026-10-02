<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Daily records
        Schema::create('daily_records', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('flock_id');
            $table->date('business_date');
            $table->uuid('feed_type_id');
            $table->decimal('feed_kg', 14, 2);
            $table->integer('eggs_count');
            $table->integer('mortality_count')->nullable();
            $table->jsonb('population_change')->nullable();
            $table->string('condition', 20); // normal, anomaly, sick, molting
            $table->text('notes')->nullable();
            $table->integer('version')->default(1);
            $table->uuid('recorded_by');
            $table->timestampTz('accepted_at');
            $table->timestampTz('updated_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('flock_id')->references('id')->on('flocks')->cascadeOnDelete();
            $table->foreign('feed_type_id')->references('id')->on('feed_types')->cascadeOnDelete();
            $table->foreign('recorded_by')->references('id')->on('users')->cascadeOnDelete();

            $table->unique(['farm_id', 'flock_id', 'business_date']);
            $table->index(['farm_id', 'business_date', 'flock_id']);
        });
        DB::statement('ALTER TABLE daily_records ADD CONSTRAINT feed_kg_nonnegative CHECK (feed_kg >= 0)');
        DB::statement('ALTER TABLE daily_records ADD CONSTRAINT eggs_count_nonnegative CHECK (eggs_count >= 0)');

        // Connect daily_record_id foreign keys from feed_entries & population_entries
        Schema::table('feed_entries', function (Blueprint $table) {
            $table->foreign('daily_record_id')->references('id')->on('daily_records')->nullOnDelete();
        });
        Schema::table('population_entries', function (Blueprint $table) {
            $table->foreign('daily_record_id')->references('id')->on('daily_records')->nullOnDelete();
        });

        // 2. Daily revisions
        Schema::create('daily_revisions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('daily_record_id');
            $table->integer('version');
            $table->jsonb('snapshot');
            $table->text('reason')->nullable();
            $table->uuid('actor_id');
            $table->timestampTz('accepted_at');

            $table->foreign('daily_record_id')->references('id')->on('daily_records')->cascadeOnDelete();
            $table->foreign('actor_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['daily_record_id', 'version']);
        });

        // 3. Task templates
        Schema::create('task_templates', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('cage_id');
            $table->uuid('assignee_id');
            $table->string('title', 120);
            $table->string('kind', 20); // feeding, cleaning, vaccination, inspection
            $table->text('sop');
            $table->date('start_on');
            $table->date('end_on')->nullable();
            $table->time('local_time');
            $table->string('recurrence', 20); // daily, weekly, monthly
            $table->boolean('active')->default(true);
            $table->integer('version')->default(1);
            $table->timestampTz('updated_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('cage_id')->references('id')->on('cages')->cascadeOnDelete();
            $table->foreign('assignee_id')->references('id')->on('users')->cascadeOnDelete();
        });

        // 4. Task runs
        Schema::create('task_runs', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('template_id');
            $table->uuid('cage_id');
            $table->date('business_date');
            $table->uuid('assignee_id');
            $table->jsonb('snapshot');
            $table->string('status', 20); // pending, completed, skipped, missed
            $table->integer('version')->default(1);
            $table->timestampTz('updated_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('template_id')->references('id')->on('task_templates')->cascadeOnDelete();
            $table->foreign('cage_id')->references('id')->on('cages')->cascadeOnDelete();
            $table->foreign('assignee_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['template_id', 'business_date']);
            $table->index(['farm_id', 'assignee_id', 'business_date']);
        });

        // 5. Task results
        Schema::create('task_results', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('task_run_id');
            $table->uuid('actor_id');
            $table->string('status', 20); // completed, missed, skipped
            $table->text('notes')->nullable();
            $table->jsonb('checklist_values');
            $table->timestampTz('accepted_at');

            $table->foreign('task_run_id')->references('id')->on('task_runs')->cascadeOnDelete();
            $table->foreign('actor_id')->references('id')->on('users')->cascadeOnDelete();
        });

        // 6. Incidents
        Schema::create('incidents', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('cage_id');
            $table->uuid('flock_id')->nullable();
            $table->uuid('source_daily_record_id')->nullable();
            $table->timestampTz('observed_at');
            $table->text('observation');
            $table->string('attention', 20); // low, medium, urgent
            $table->uuid('assignee_id')->nullable();
            $table->string('status', 20); // open, in_progress, resolved, closed
            $table->integer('version')->default(1);
            $table->uuid('recorded_by');
            $table->timestampTz('accepted_at');
            $table->timestampTz('updated_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('cage_id')->references('id')->on('cages')->cascadeOnDelete();
            $table->foreign('flock_id')->references('id')->on('flocks')->nullOnDelete();
            $table->foreign('source_daily_record_id')->references('id')->on('daily_records')->nullOnDelete();
            $table->foreign('assignee_id')->references('id')->on('users')->nullOnDelete();
            $table->foreign('recorded_by')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['farm_id', 'cage_id', 'status', 'updated_at']);
        });

        // 7. Incident actions
        Schema::create('incident_actions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('incident_id');
            $table->uuid('actor_id');
            $table->string('action_kind', 20); // assign, action, resolve, close
            $table->text('notes');
            $table->string('status', 20); // status after action
            $table->timestampTz('accepted_at');

            $table->foreign('incident_id')->references('id')->on('incidents')->cascadeOnDelete();
            $table->foreign('actor_id')->references('id')->on('users')->cascadeOnDelete();
        });

        // 8. Attachments
        Schema::create('attachments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->string('parent_type', 20); // incident, task_result, daily_record
            $table->uuid('parent_id');
            $table->text('storage_key');
            $table->string('source_sha256', 64);
            $table->string('media_type', 32);
            $table->integer('byte_size');
            $table->uuid('uploaded_by');
            $table->timestampTz('accepted_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('uploaded_by')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['farm_id', 'parent_type', 'parent_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attachments');
        Schema::dropIfExists('incident_actions');
        Schema::dropIfExists('incidents');
        Schema::dropIfExists('task_results');
        Schema::dropIfExists('task_runs');
        Schema::dropIfExists('task_templates');
        Schema::dropIfExists('daily_revisions');
        Schema::table('population_entries', function (Blueprint $table) {
            $table->dropForeign(['daily_record_id']);
        });
        Schema::table('feed_entries', function (Blueprint $table) {
            $table->dropForeign(['daily_record_id']);
        });
        Schema::dropIfExists('daily_records');
    }
};
