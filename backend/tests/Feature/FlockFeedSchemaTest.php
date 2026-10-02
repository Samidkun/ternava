<?php

namespace Tests\Feature;

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class FlockFeedSchemaTest extends TestCase
{
    use RefreshDatabase;

    private string $farmId;

    protected function setUp(): void
    {
        parent::setUp();

        $this->farmId = (string) str()->uuid();
        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Test Flock Feed',
            'location' => 'Blitar',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);
    }

    public function test_negative_balance_is_rejected_by_database(): void
    {
        $feedTypeId = (string) str()->uuid();
        DB::table('feed_types')->insert([
            'id' => $feedTypeId,
            'farm_id' => $this->farmId,
            'code' => 'FEED-01',
            'name' => 'Konsentrat Starter',
            'minimum_kg' => 10.00,
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        $balanceId = (string) str()->uuid();
        DB::table('feed_balances')->insert([
            'id' => $balanceId,
            'farm_id' => $this->farmId,
            'feed_type_id' => $feedTypeId,
            'quantity_kg' => '50.00',
            'updated_at' => now(),
        ]);

        $this->expectException(QueryException::class);

        // Attempt to update balance to negative
        DB::table('feed_balances')
            ->where('id', $balanceId)
            ->update(['quantity_kg' => '-0.01']);
    }

    public function test_only_one_active_flock_per_cage(): void
    {
        $cageId = (string) str()->uuid();
        DB::table('cages')->insert([
            'id' => $cageId,
            'farm_id' => $this->farmId,
            'code' => 'C-01',
            'name' => 'Kandang 1',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        // First active flock (finished_on is null)
        DB::table('flocks')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $this->farmId,
            'cage_id' => $cageId,
            'code' => 'FL-01',
            'placed_on' => '2026-01-01',
            'finished_on' => null,
            'initial_population' => 100,
            'recorded_population' => 100,
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->expectException(QueryException::class);

        // Second active flock in same cage must fail
        DB::table('flocks')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $this->farmId,
            'cage_id' => $cageId,
            'code' => 'FL-02',
            'placed_on' => '2026-02-01',
            'finished_on' => null,
            'initial_population' => 120,
            'recorded_population' => 120,
            'version' => 1,
            'updated_at' => now(),
        ]);
    }

    public function test_case_folded_cage_code_unique_in_farm(): void
    {
        DB::table('cages')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $this->farmId,
            'code' => 'KANDANG-A',
            'name' => 'Kandang A',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->expectException(QueryException::class);

        DB::table('cages')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $this->farmId,
            'code' => 'kandang-a',
            'name' => 'Kandang A Duplikat',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);
    }
}
