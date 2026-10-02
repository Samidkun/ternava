<?php

namespace Tests\Feature;

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class OperationsSchemaTest extends TestCase
{
    use RefreshDatabase;

    private string $farmId;

    private string $cageId;

    private string $flockId;

    private string $feedTypeId;

    private string $userId;

    protected function setUp(): void
    {
        parent::setUp();

        $this->farmId = (string) str()->uuid();
        $this->cageId = (string) str()->uuid();
        $this->flockId = (string) str()->uuid();
        $this->feedTypeId = (string) str()->uuid();
        $this->userId = (string) str()->uuid();

        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Operations Test',
            'location' => 'Malang',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('users')->insert([
            'id' => $this->userId,
            'username' => 'operator_budi',
            'display_name' => 'Budi',
            'password_hash' => 'hash',
            'must_change_password' => false,
            'active' => true,
        ]);

        DB::table('cages')->insert([
            'id' => $this->cageId,
            'farm_id' => $this->farmId,
            'code' => 'K-OPS-1',
            'name' => 'Kandang Ops 1',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('flocks')->insert([
            'id' => $this->flockId,
            'farm_id' => $this->farmId,
            'cage_id' => $this->cageId,
            'code' => 'FL-OPS-1',
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
            'code' => 'FEED-OPS-1',
            'name' => 'Pakan Ops',
            'minimum_kg' => 0.00,
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);
    }

    public function test_daily_record_date_is_unique_per_flock(): void
    {
        $date = '2026-10-01';

        DB::table('daily_records')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $this->farmId,
            'flock_id' => $this->flockId,
            'business_date' => $date,
            'feed_type_id' => $this->feedTypeId,
            'feed_kg' => '15.00',
            'eggs_count' => 90,
            'mortality_count' => 0,
            'condition' => 'normal',
            'version' => 1,
            'recorded_by' => $this->userId,
            'accepted_at' => now(),
            'updated_at' => now(),
        ]);

        $this->expectException(QueryException::class);

        // Duplicate record on same flock and date must be rejected
        DB::table('daily_records')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $this->farmId,
            'flock_id' => $this->flockId,
            'business_date' => $date,
            'feed_type_id' => $this->feedTypeId,
            'feed_kg' => '14.00',
            'eggs_count' => 88,
            'mortality_count' => 1,
            'condition' => 'normal',
            'version' => 1,
            'recorded_by' => $this->userId,
            'accepted_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function test_incident_and_action_relationship(): void
    {
        $incidentId = (string) str()->uuid();

        DB::table('incidents')->insert([
            'id' => $incidentId,
            'farm_id' => $this->farmId,
            'cage_id' => $this->cageId,
            'flock_id' => $this->flockId,
            'observed_at' => now(),
            'observation' => 'Talang air bocor di kandang A',
            'attention' => 'medium',
            'status' => 'open',
            'version' => 1,
            'recorded_by' => $this->userId,
            'accepted_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('incident_actions')->insert([
            'id' => (string) str()->uuid(),
            'incident_id' => $incidentId,
            'actor_id' => $this->userId,
            'action_kind' => 'action',
            'notes' => 'Talang air telah ditambal dengan seal karet',
            'status' => 'resolved',
            'accepted_at' => now(),
        ]);

        $count = DB::table('incident_actions')->where('incident_id', $incidentId)->count();
        $this->assertSame(1, $count);
    }
}
