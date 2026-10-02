<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class ReviseDailyTest extends TestCase
{
    use RefreshDatabase;

    private string $farmId;

    private string $cageId;

    private string $flockId;

    private string $feedTypeId;

    private User $owner;

    private User $operator;

    private string $dailyRecordId;

    protected function setUp(): void
    {
        parent::setUp();

        $this->farmId = (string) Str::uuid();
        $this->cageId = (string) Str::uuid();
        $this->flockId = (string) Str::uuid();
        $this->feedTypeId = (string) Str::uuid();

        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Revise Test',
            'location' => 'Kediri',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->owner = new User([
            'id' => (string) Str::uuid(),
            'username' => 'owner_revisi',
            'display_name' => 'Owner Revisi',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->owner->save();

        $this->operator = new User([
            'id' => (string) Str::uuid(),
            'username' => 'operator_revisi',
            'display_name' => 'Operator Revisi',
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
            'code' => 'K-REV-01',
            'name' => 'Kandang Revisi 1',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('flocks')->insert([
            'id' => $this->flockId,
            'farm_id' => $this->farmId,
            'cage_id' => $this->cageId,
            'code' => 'FL-REV-01',
            'placed_on' => '2026-01-01',
            'finished_on' => null,
            'initial_population' => 100,
            'recorded_population' => 100,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('feed_types')->insert([
            'id' => $this->feedTypeId,
            'farm_id' => $this->farmId,
            'code' => 'FEED-REV-01',
            'name' => 'Pakan Revisi',
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

        $this->dailyRecordId = (string) Str::uuid();
        DB::table('daily_records')->insert([
            'id' => $this->dailyRecordId,
            'farm_id' => $this->farmId,
            'flock_id' => $this->flockId,
            'business_date' => '2026-10-01',
            'feed_type_id' => $this->feedTypeId,
            'feed_kg' => '20.00',
            'eggs_count' => 90,
            'mortality_count' => 0,
            'condition' => 'normal',
            'version' => 1,
            'recorded_by' => $this->owner->id,
            'accepted_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function test_stale_revision_changes_nothing(): void
    {
        $key1 = (string) Str::uuid();

        // First revision: version increments to 2
        $rev1 = $this->actingAs($this->owner)
            ->withHeader('Idempotency-Key', $key1)
            ->postJson('/api/v1/daily-records/'.$this->dailyRecordId.'/revisions', [
                'base_version' => 1,
                'flock_id' => $this->flockId,
                'business_date' => '2026-10-01',
                'feed_type_id' => $this->feedTypeId,
                'feed_kg' => '18.00', // Reduced by 2 kg
                'eggs_count' => 92,
                'mortality_count' => 0,
                'condition' => 'normal',
                'reason' => 'Koreksi penimbangan timbangan digital',
            ]);

        $rev1->assertOk()
            ->assertJsonPath('data.status', 'accepted')
            ->assertJsonPath('data.version', 2);

        // Feed balance was compensated: 300.00 - 18.00 (instead of 20.00) = 302.00 (reversal +2.00)
        // Check feed_balances: 300.00 - (-20.00 + 18.00) -> 300.00 + 2.00 = 302.00
        $this->assertDatabaseHas('feed_balances', [
            'feed_type_id' => $this->feedTypeId,
            'quantity_kg' => '302.00',
        ]);

        // Stale revision: trying to revise again using base_version = 1 must return 409 VERSION_CONFLICT
        $key2 = (string) Str::uuid();
        $staleRev = $this->actingAs($this->owner)
            ->withHeader('Idempotency-Key', $key2)
            ->postJson('/api/v1/daily-records/'.$this->dailyRecordId.'/revisions', [
                'base_version' => 1, // Stale! Current version is 2
                'flock_id' => $this->flockId,
                'business_date' => '2026-10-01',
                'feed_type_id' => $this->feedTypeId,
                'feed_kg' => '17.00',
                'eggs_count' => 95,
                'mortality_count' => 0,
                'condition' => 'normal',
                'reason' => 'Revisi stale',
            ]);

        $staleRev->assertStatus(409)
            ->assertJsonPath('error.code', 'VERSION_CONFLICT')
            ->assertJsonPath('error.current_version', 2);

        // Exactly 1 revision recorded in daily_revisions archive
        $this->assertDatabaseCount('daily_revisions', 1);
    }

    public function test_operator_cannot_revise_daily_records(): void
    {
        $res = $this->actingAs($this->operator)
            ->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson('/api/v1/daily-records/'.$this->dailyRecordId.'/revisions', [
                'base_version' => 1,
                'flock_id' => $this->flockId,
                'business_date' => '2026-10-01',
                'feed_type_id' => $this->feedTypeId,
                'feed_kg' => '18.00',
                'eggs_count' => 92,
                'mortality_count' => 0,
                'condition' => 'normal',
                'reason' => 'Percobaan revisi operator',
            ]);

        $res->assertForbidden();
    }
}
