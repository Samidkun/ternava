<?php

namespace Tests\Feature;

use App\Models\User;
use App\Sync\CursorCodec;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class SyncTest extends TestCase
{
    use RefreshDatabase;

    private string $farmId;

    private User $operator;

    private string $membershipId;

    private string $cageId;

    private string $flockId;

    private string $feedTypeId;

    protected function setUp(): void
    {
        parent::setUp();

        $this->farmId = (string) Str::uuid();
        $this->cageId = (string) Str::uuid();
        $this->flockId = (string) Str::uuid();
        $this->feedTypeId = (string) Str::uuid();

        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Sync Test',
            'location' => 'Malang',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->operator = new User([
            'id' => (string) Str::uuid(),
            'username' => 'operator_sync',
            'display_name' => 'Operator Sync',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->operator->save();

        $this->membershipId = (string) Str::uuid();
        DB::table('memberships')->insert([
            'id' => $this->membershipId,
            'farm_id' => $this->farmId,
            'user_id' => $this->operator->id,
            'role' => 'operator',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        DB::table('cages')->insert([
            'id' => $this->cageId,
            'farm_id' => $this->farmId,
            'code' => 'K-SYNC-01',
            'name' => 'Kandang Sync',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('cage_assignments')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'membership_id' => $this->membershipId,
            'cage_id' => $this->cageId,
        ]);

        DB::table('flocks')->insert([
            'id' => $this->flockId,
            'farm_id' => $this->farmId,
            'cage_id' => $this->cageId,
            'code' => 'FL-SYNC-01',
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
            'code' => 'FEED-SYNC-01',
            'name' => 'Pakan Sync',
            'minimum_kg' => 0.00,
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('feed_balances')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'feed_type_id' => $this->feedTypeId,
            'quantity_kg' => '500.00',
            'updated_at' => now(),
        ]);

        // Insert some sync changes
        DB::table('sync_counters')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'last_sequence' => 2,
        ]);

        DB::table('sync_changes')->insert([
            [
                'id' => (string) Str::uuid(),
                'farm_id' => $this->farmId,
                'sequence' => 1,
                'resource_type' => 'cage',
                'resource_id' => $this->cageId,
                'action' => 'upsert',
                'snapshot' => json_encode(['id' => $this->cageId, 'name' => 'Kandang Sync']),
                'accepted_at' => now(),
            ],
            [
                'id' => (string) Str::uuid(),
                'farm_id' => $this->farmId,
                'sequence' => 2,
                'resource_type' => 'flock',
                'resource_id' => $this->flockId,
                'action' => 'upsert',
                'snapshot' => json_encode(['id' => $this->flockId, 'code' => 'FL-SYNC-01']),
                'accepted_at' => now(),
            ],
        ]);
    }

    public function test_bootstrap_pages_exclude_newer_writes(): void
    {
        // 1. Initial bootstrap call with limit 1
        $res1 = $this->actingAs($this->operator)
            ->getJson('/api/v1/sync/bootstrap?limit=1');

        $res1->assertOk()
            ->assertJsonPath('data.has_more', true);

        $cursor = $res1->json('data.next_cursor');
        $this->assertNotEmpty($cursor);

        // 2. A newer write lands after bootstrap started (sequence = 3)
        $newDailyId = (string) Str::uuid();
        DB::table('sync_counters')->where('farm_id', $this->farmId)->update(['last_sequence' => 3]);
        DB::table('sync_changes')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'sequence' => 3,
            'resource_type' => 'daily_record',
            'resource_id' => $newDailyId,
            'action' => 'upsert',
            'snapshot' => json_encode(['id' => $newDailyId, 'eggs_count' => 90]),
            'accepted_at' => now(),
        ]);

        // 3. Fetching next page of bootstrap with the cursor
        $res2 = $this->actingAs($this->operator)
            ->getJson('/api/v1/sync/bootstrap?cursor='.urlencode((string) $cursor));

        $res2->assertOk();
        $changes = $res2->json('data.changes');
        $resourceIds = array_column($changes, 'resource_id');

        // Must EXCLUDE the newer write ($newDailyId) because bootstrap is pinned to watermark = 2!
        $this->assertNotContains($newDailyId, $resourceIds);

        // 4. Calling /sync/changes with cursor will INCLUDE the newer write ($newDailyId)
        $deltaRes = $this->actingAs($this->operator)
            ->getJson('/api/v1/sync/changes?cursor='.urlencode((string) $cursor));

        $deltaRes->assertOk();
        $deltaChanges = $deltaRes->json('data.changes');
        $deltaIds = array_column($deltaChanges, 'resource_id');

        $this->assertContains($newDailyId, $deltaIds);
    }

    public function test_tampered_or_expired_cursor_returns_409(): void
    {
        // 1. Tampered cursor
        $resTampered = $this->actingAs($this->operator)
            ->getJson('/api/v1/sync/changes?cursor=invalid.tampered_signature');
        $resTampered->assertStatus(409)
            ->assertJsonPath('error.code', 'CURSOR_RESET_REQUIRED');

        // 2. Expired cursor
        $expiredCursor = CursorCodec::encode([
            'farm_id' => $this->farmId,
            'actor_id' => $this->operator->id,
            'scope_version' => 1,
            'high_watermark' => 2,
            'last_sequence' => 2,
            'expires_at' => now()->subMinute()->timestamp, // Expired 1 minute ago
        ]);

        $resExpired = $this->actingAs($this->operator)
            ->getJson('/api/v1/sync/changes?cursor='.urlencode($expiredCursor));
        $resExpired->assertStatus(409)
            ->assertJsonPath('error.code', 'CURSOR_RESET_REQUIRED');
    }
}
