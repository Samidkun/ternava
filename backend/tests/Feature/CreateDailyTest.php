<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class CreateDailyTest extends TestCase
{
    use RefreshDatabase;

    private string $farmId;

    private string $assignedCageId;

    private string $hiddenCageId;

    private string $flockId;

    private string $hiddenFlockId;

    private string $feedTypeId;

    private User $owner;

    private User $operator;

    protected function setUp(): void
    {
        parent::setUp();

        $this->farmId = (string) Str::uuid();
        $this->assignedCageId = (string) Str::uuid();
        $this->hiddenCageId = (string) Str::uuid();
        $this->flockId = (string) Str::uuid();
        $this->hiddenFlockId = (string) Str::uuid();
        $this->feedTypeId = (string) Str::uuid();

        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Daily Test',
            'location' => 'Blitar',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->owner = new User([
            'id' => (string) Str::uuid(),
            'username' => 'owner_daily',
            'display_name' => 'Owner Daily',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->owner->save();

        $this->operator = new User([
            'id' => (string) Str::uuid(),
            'username' => 'operator_daily',
            'display_name' => 'Operator Daily',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->operator->save();

        DB::table('memberships')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'user_id' => $this->owner->id,
            'role' => 'owner',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        $operatorMembershipId = (string) Str::uuid();
        DB::table('memberships')->insert([
            'id' => $operatorMembershipId,
            'farm_id' => $this->farmId,
            'user_id' => $this->operator->id,
            'role' => 'operator',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        DB::table('cages')->insert([
            [
                'id' => $this->assignedCageId,
                'farm_id' => $this->farmId,
                'code' => 'K-DAY-01',
                'name' => 'Kandang Ditugaskan',
                'active' => true,
                'version' => 1,
                'updated_at' => now(),
            ],
            [
                'id' => $this->hiddenCageId,
                'farm_id' => $this->farmId,
                'code' => 'K-DAY-02',
                'name' => 'Kandang Tersembunyi',
                'active' => true,
                'version' => 1,
                'updated_at' => now(),
            ],
        ]);

        // Operator assigned ONLY to cage 1
        DB::table('cage_assignments')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'membership_id' => $operatorMembershipId,
            'cage_id' => $this->assignedCageId,
        ]);

        DB::table('flocks')->insert([
            [
                'id' => $this->flockId,
                'farm_id' => $this->farmId,
                'cage_id' => $this->assignedCageId,
                'code' => 'FL-DAY-01',
                'placed_on' => '2026-01-01',
                'finished_on' => null,
                'initial_population' => 100,
                'recorded_population' => 100,
                'version' => 1,
                'updated_at' => now(),
            ],
            [
                'id' => $this->hiddenFlockId,
                'farm_id' => $this->farmId,
                'cage_id' => $this->hiddenCageId,
                'code' => 'FL-DAY-02',
                'placed_on' => '2026-01-01',
                'finished_on' => null,
                'initial_population' => 100,
                'recorded_population' => 100,
                'version' => 1,
                'updated_at' => now(),
            ],
        ]);

        DB::table('feed_types')->insert([
            'id' => $this->feedTypeId,
            'farm_id' => $this->farmId,
            'code' => 'FEED-DAY-01',
            'name' => 'Pakan Layer Standar',
            'minimum_kg' => 0.00,
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('feed_balances')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'feed_type_id' => $this->feedTypeId,
            'quantity_kg' => '300.00',
            'updated_at' => now(),
        ]);
    }

    public function test_create_daily_record_atomically_deducts_feed_and_records_population(): void
    {
        $key = (string) Str::uuid();
        $date = now()->format('Y-m-d');

        $res = $this->actingAs($this->operator)
            ->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/daily-records', [
                'flock_id' => $this->flockId,
                'business_date' => $date,
                'feed_type_id' => $this->feedTypeId,
                'feed_kg' => '15.50',
                'eggs_count' => 92,
                'mortality_count' => 2,
                'condition' => 'normal',
                'notes' => 'Ayam sehat produksi stabil',
            ]);

        $res->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        // Check daily record inserted
        $this->assertDatabaseHas('daily_records', [
            'farm_id' => $this->farmId,
            'flock_id' => $this->flockId,
            'business_date' => $date,
            'feed_kg' => '15.50',
            'eggs_count' => 92,
            'mortality_count' => 2,
        ]);

        // Check feed balance reduced: 300.00 - 15.50 = 284.50
        $this->assertDatabaseHas('feed_balances', [
            'feed_type_id' => $this->feedTypeId,
            'quantity_kg' => '284.50',
        ]);

        // Check feed entry created
        $this->assertDatabaseHas('feed_entries', [
            'feed_type_id' => $this->feedTypeId,
            'kind' => 'daily_usage',
            'delta_kg' => '15.50',
        ]);

        // Check population entry created for mortality (-2)
        $this->assertDatabaseHas('population_entries', [
            'flock_id' => $this->flockId,
            'delta_count' => -2,
        ]);
    }

    public function test_duplicate_daily_record_returns_409(): void
    {
        $date = '2026-09-01';

        DB::table('daily_records')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'flock_id' => $this->flockId,
            'business_date' => $date,
            'feed_type_id' => $this->feedTypeId,
            'feed_kg' => '10.00',
            'eggs_count' => 80,
            'mortality_count' => 0,
            'condition' => 'normal',
            'version' => 1,
            'recorded_by' => $this->operator->id,
            'accepted_at' => now(),
            'updated_at' => now(),
        ]);

        $res = $this->actingAs($this->operator)
            ->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson('/api/v1/daily-records', [
                'flock_id' => $this->flockId,
                'business_date' => $date,
                'feed_type_id' => $this->feedTypeId,
                'feed_kg' => '12.00',
                'eggs_count' => 85,
                'mortality_count' => 0,
                'condition' => 'normal',
            ]);

        $res->assertStatus(409)
            ->assertJsonPath('error.code', 'DAILY_ALREADY_EXISTS');
    }

    public function test_insufficient_feed_rolls_back_every_business_effect(): void
    {
        $key = (string) Str::uuid();

        // Feed balance is 300.00, requesting 350.00 will fail
        $res = $this->actingAs($this->operator)
            ->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/daily-records', [
                'flock_id' => $this->flockId,
                'business_date' => now()->format('Y-m-d'),
                'feed_type_id' => $this->feedTypeId,
                'feed_kg' => '350.00',
                'eggs_count' => 80,
                'mortality_count' => 1,
                'condition' => 'normal',
            ]);

        $res->assertStatus(422)
            ->assertJsonPath('error.code', 'INSUFFICIENT_STOCK');

        // Verify zero records were created and feed balance was not modified
        $this->assertDatabaseCount('daily_records', 0);
        $this->assertDatabaseCount('feed_entries', 0);
        $this->assertDatabaseCount('population_entries', 0);
        $this->assertDatabaseHas('feed_balances', [
            'feed_type_id' => $this->feedTypeId,
            'quantity_kg' => '300.00',
        ]);
    }

    public function test_operator_cannot_record_unassigned_flock(): void
    {
        $res = $this->actingAs($this->operator)
            ->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson('/api/v1/daily-records', [
                'flock_id' => $this->hiddenFlockId, // In cage K-DAY-02 which operator is NOT assigned to
                'business_date' => now()->format('Y-m-d'),
                'feed_type_id' => $this->feedTypeId,
                'feed_kg' => '10.00',
                'eggs_count' => 80,
                'condition' => 'normal',
            ]);

        $res->assertForbidden();
    }
}
