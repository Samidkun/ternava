<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class FlockTest extends TestCase
{
    use RefreshDatabase;

    private string $farmId;

    private string $cageId;

    private string $feedTypeId;

    private User $owner;

    private User $operator;

    private string $flockId;

    protected function setUp(): void
    {
        parent::setUp();

        $this->farmId = (string) Str::uuid();
        $this->cageId = (string) Str::uuid();
        $this->flockId = (string) Str::uuid();
        $this->feedTypeId = (string) Str::uuid();

        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Petelur Jaya',
            'location' => 'Blitar',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->owner = new User([
            'id' => (string) Str::uuid(),
            'username' => 'owner_bambang',
            'display_name' => 'Bambang',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->owner->save();

        $this->operator = new User([
            'id' => (string) Str::uuid(),
            'username' => 'operator_agus',
            'display_name' => 'Agus',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->operator->save();

        DB::table('memberships')->insert([
            [
                'id' => (string) Str::uuid(),
                'farm_id' => $this->farmId,
                'user_id' => $this->owner->id,
                'role' => 'owner',
                'scope_version' => 1,
                'version' => 1,
                'active' => true,
            ],
            [
                'id' => (string) Str::uuid(),
                'farm_id' => $this->farmId,
                'user_id' => $this->operator->id,
                'role' => 'operator',
                'scope_version' => 1,
                'version' => 1,
                'active' => true,
            ],
        ]);

        DB::table('cages')->insert([
            'id' => $this->cageId,
            'farm_id' => $this->farmId,
            'code' => 'K-FL-01',
            'name' => 'Kandang Layer 1',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('feed_types')->insert([
            'id' => $this->feedTypeId,
            'farm_id' => $this->farmId,
            'code' => 'FEED-L-01',
            'name' => 'Pakan Layer Super',
            'minimum_kg' => 0.00,
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('flocks')->insert([
            'id' => $this->flockId,
            'farm_id' => $this->farmId,
            'cage_id' => $this->cageId,
            'code' => 'FLOCK-2026-A',
            'placed_on' => '2026-01-01',
            'finished_on' => null,
            'initial_population' => 100,
            'recorded_population' => 100,
            'version' => 1,
            'updated_at' => now(),
        ]);
    }

    public function test_initial_population_cannot_change_after_daily(): void
    {
        // Insert an existing daily record for this flock
        DB::table('daily_records')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'flock_id' => $this->flockId,
            'business_date' => '2026-01-02',
            'feed_type_id' => $this->feedTypeId,
            'feed_kg' => '10.00',
            'eggs_count' => 80,
            'mortality_count' => 1,
            'condition' => 'normal',
            'version' => 1,
            'recorded_by' => $this->operator->id,
            'accepted_at' => now(),
            'updated_at' => now(),
        ]);

        // Attempting to update initial_population after daily records exist must fail with 422
        $key = (string) Str::uuid();
        $res = $this->actingAs($this->owner)
            ->withHeader('Idempotency-Key', $key)
            ->patchJson('/api/v1/flocks/'.$this->flockId, [
                'base_version' => 1,
                'code' => 'FLOCK-2026-A',
                'status' => 'active',
                'finished_on' => null,
                'initial_population' => 120, // Different from 100
                'reason' => 'Koreksi populasi awal',
            ]);

        $res->assertStatus(422);
    }

    public function test_can_finish_flock_with_finished_date(): void
    {
        $key = (string) Str::uuid();
        $res = $this->actingAs($this->owner)
            ->withHeader('Idempotency-Key', $key)
            ->patchJson('/api/v1/flocks/'.$this->flockId, [
                'base_version' => 1,
                'code' => 'FLOCK-2026-A',
                'status' => 'finished',
                'finished_on' => '2026-09-30',
                'initial_population' => 100,
                'reason' => 'Kelompok afkir selesai produksi',
            ]);

        $res->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        $this->assertDatabaseHas('flocks', [
            'id' => $this->flockId,
            'finished_on' => '2026-09-30',
        ]);
    }

    public function test_creating_two_active_flocks_in_same_cage_fails(): void
    {
        $key = (string) Str::uuid();
        // Cage already has active flock FLOCK-2026-A
        $res = $this->actingAs($this->owner)
            ->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/flocks', [
                'cage_id' => $this->cageId,
                'code' => 'FLOCK-2026-B',
                'placed_on' => '2026-02-01',
                'initial_population' => 120,
                'status' => 'active',
                'finished_on' => null,
            ]);

        $res->assertStatus(409);
    }
}
