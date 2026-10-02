<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Farms table
        Schema::create('farms', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name', 100);
            $table->string('location', 200);
            $table->string('timezone', 50)->default('Asia/Jakarta');
            $table->string('currency', 3)->default('IDR');
            $table->integer('version')->default(1);
            $table->timestampTz('updated_at');
        });

        // 2. Recreate users table to match schema.json (UUID primary key)
        Schema::dropIfExists('users');
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('username', 80)->unique();
            $table->string('display_name', 100);
            $table->text('password_hash');
            $table->boolean('must_change_password')->default(false);
            $table->boolean('active')->default(true);
            $table->timestamps();
        });
        DB::statement('CREATE UNIQUE INDEX username_folded ON users (lower(username))');

        // 3. Memberships table
        Schema::create('memberships', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('user_id');
            $table->string('role', 20); // owner, admin, operator
            $table->bigInteger('scope_version')->default(1);
            $table->integer('version')->default(1);
            $table->boolean('active')->default(true);

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->unique(['farm_id', 'user_id']);
            $table->index(['farm_id', 'active']);
        });
        DB::statement("CREATE UNIQUE INDEX one_active_owner ON memberships (farm_id) WHERE role = 'owner' AND active = true");

        // 4. Device sessions table
        Schema::create('device_sessions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('user_id');
            $table->uuid('device_id');
            $table->string('token_hash', 64)->unique();
            $table->timestampTz('expires_at');
            $table->timestampTz('revoked_at')->nullable();

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
            $table->index(['user_id', 'device_id']);
        });

        // 5. Cage assignments table (cages FK added in T05)
        Schema::create('cage_assignments', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('farm_id');
            $table->uuid('membership_id');
            $table->uuid('cage_id');

            $table->foreign('farm_id')->references('id')->on('farms')->cascadeOnDelete();
            $table->foreign('membership_id')->references('id')->on('memberships')->cascadeOnDelete();
            $table->unique(['membership_id', 'cage_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('cage_assignments');
        Schema::dropIfExists('device_sessions');
        Schema::dropIfExists('memberships');
        Schema::dropIfExists('users');
        Schema::dropIfExists('farms');
    }
};
