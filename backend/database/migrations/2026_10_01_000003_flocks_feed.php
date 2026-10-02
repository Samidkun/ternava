<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Cages table
        Schema::create('cages', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->string('code', 32);
            $table->string('name', 100);
            $table->text('description')->nullable();
            $table->boolean('active')->default(true);
            $table->integer('version')->default(1);
            $table->timestampTz('updated_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->index(['farm_id', 'active']);
        });
        DB::statement('CREATE UNIQUE INDEX cage_code_folded ON cages (farm_id, lower(code))');

        // Connect cage_assignments FK to cages
        Schema::table('cage_assignments', function (Blueprint $table) {
            $table->foreign('cage_id')->references('id')->on('cages')->cascadeOnDelete();
        });

        // 2. Flocks table
        Schema::create('flocks', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('cage_id');
            $table->string('code', 32);
            $table->date('placed_on');
            $table->date('finished_on')->nullable();
            $table->integer('initial_population');
            $table->integer('recorded_population');
            $table->integer('version')->default(1);
            $table->timestampTz('updated_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('cage_id')->references('id')->on('cages')->cascadeOnDelete();
            $table->index(['farm_id', 'cage_id', 'placed_on']);
        });
        DB::statement('CREATE UNIQUE INDEX flock_code_folded ON flocks (farm_id, lower(code))');
        DB::statement('CREATE UNIQUE INDEX one_active_flock ON flocks (cage_id) WHERE finished_on IS NULL');

        // 3. Feed types table
        Schema::create('feed_types', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->string('code', 32);
            $table->string('name', 100);
            $table->decimal('minimum_kg', 14, 2)->default(0);
            $table->boolean('active')->default(true);
            $table->integer('version')->default(1);
            $table->timestampTz('updated_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
        });
        DB::statement('CREATE UNIQUE INDEX feed_type_code_folded ON feed_types (farm_id, lower(code))');

        // 4. Feed balances table
        Schema::create('feed_balances', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('feed_type_id');
            $table->decimal('quantity_kg', 14, 2)->default(0);
            $table->timestampTz('updated_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('feed_type_id')->references('id')->on('feed_types')->cascadeOnDelete();
            $table->unique(['farm_id', 'feed_type_id']);
        });
        DB::statement('ALTER TABLE feed_balances ADD CONSTRAINT balance_nonnegative CHECK (quantity_kg >= 0)');

        // 5. Feed entries table
        Schema::create('feed_entries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('feed_type_id');
            $table->date('business_date');
            $table->string('kind', 20); // opening, purchase, usage, adjustment, reversal
            $table->decimal('delta_kg', 14, 2);
            $table->decimal('unit_price_idr', 18, 2)->nullable();
            $table->decimal('purchase_total_idr', 18, 2)->nullable();
            $table->text('supplier')->nullable();
            $table->text('reason')->nullable();
            $table->uuid('daily_record_id')->nullable();
            $table->integer('daily_version')->nullable();
            $table->uuid('reverses_entry_id')->nullable();
            $table->timestampTz('accepted_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('feed_type_id')->references('id')->on('feed_types')->cascadeOnDelete();
            $table->index(['farm_id', 'feed_type_id', 'accepted_at', 'id']);
        });
        Schema::table('feed_entries', function (Blueprint $table) {
            $table->foreign('reverses_entry_id')->references('id')->on('feed_entries')->nullOnDelete();
        });
        DB::statement("CREATE UNIQUE INDEX one_opening_per_feed ON feed_entries (farm_id, feed_type_id) WHERE kind = 'opening'");

        // 6. Population entries table
        Schema::create('population_entries', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('flock_id');
            $table->date('business_date');
            $table->integer('delta_count');
            $table->uuid('daily_record_id')->nullable();
            $table->integer('daily_version')->nullable();
            $table->text('reason')->nullable();
            $table->timestampTz('accepted_at');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('flock_id')->references('id')->on('flocks')->cascadeOnDelete();
            $table->index(['farm_id', 'flock_id', 'accepted_at', 'id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('population_entries');
        Schema::dropIfExists('feed_entries');
        Schema::dropIfExists('feed_balances');
        Schema::dropIfExists('feed_types');
        Schema::dropIfExists('flocks');
        Schema::table('cage_assignments', function (Blueprint $table) {
            $table->dropForeign(['cage_id']);
        });
        Schema::dropIfExists('cages');
    }
};
