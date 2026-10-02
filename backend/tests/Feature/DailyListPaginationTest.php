<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Scenario;
use Tests\TestCase;

/**
 * T44 — GET /daily-records must honour the contract's pagination.
 *
 * openapi.json declares listDaily with `limit` (1..100), `cursor`, `from`, `to`
 * and a DailyPage response (data maxItems 100 + meta{next_cursor,has_more,as_of}).
 * The load benchmark exposed that the endpoint ignored all of it and returned
 * every row, which is both a contract violation and the cause of the failing
 * read p95. These tests pin the contract.
 */
class DailyListPaginationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @return array<string, mixed>
     */
    private function seedDaily(int $count): array
    {
        $f = Scenario::persist(Scenario::layerFarm());

        for ($i = 0; $i < $count; $i++) {
            DB::table('daily_records')->insert([
                'id' => (string) Str::uuid(),
                'farm_id' => $f['farm_id'],
                'flock_id' => $f['flock']['id'],
                'business_date' => sprintf('2026-06-%02d', $i + 1),
                'feed_type_id' => $f['feed']['id'],
                'feed_kg' => '10.00',
                'eggs_count' => 800,
                'mortality_count' => 0,
                'condition' => 'normal',
                'version' => 1,
                'recorded_by' => $f['operator']->id,
                'accepted_at' => now(),
                'updated_at' => now(),
            ]);
        }

        return $f;
    }

    public function test_list_is_limited_and_returns_a_cursor_meta(): void
    {
        $f = $this->seedDaily(3);

        $res = $this->actingAs($f['operator'])->getJson('/api/v1/daily-records?limit=2');

        $res->assertStatus(200);
        $res->assertJsonCount(2, 'data');
        $res->assertJsonPath('meta.has_more', true);
        $this->assertNotNull($res->json('meta.next_cursor'), 'A truncated page must expose next_cursor.');
        $this->assertNotNull($res->json('meta.as_of'));

        // The page must never exceed the contract maximum of 100.
        $this->assertLessThanOrEqual(100, count($res->json('data')));
    }

    public function test_following_the_cursor_returns_the_rest_without_overlap(): void
    {
        $f = $this->seedDaily(3);

        $first = $this->actingAs($f['operator'])->getJson('/api/v1/daily-records?limit=2');
        $firstIds = array_column($first->json('data'), 'id');
        $cursor = $first->json('meta.next_cursor');

        $second = $this->actingAs($f['operator'])
            ->getJson('/api/v1/daily-records?limit=2&cursor='.urlencode($cursor));

        $second->assertStatus(200);
        $second->assertJsonCount(1, 'data');
        $second->assertJsonPath('meta.has_more', false);

        $secondIds = array_column($second->json('data'), 'id');
        $this->assertSame([], array_intersect($firstIds, $secondIds), 'Pages must not overlap.');
        $this->assertCount(3, array_unique(array_merge($firstIds, $secondIds)), 'All rows must be reachable.');
    }

    public function test_limit_above_contract_maximum_is_rejected(): void
    {
        $f = $this->seedDaily(1);

        $this->actingAs($f['operator'])
            ->getJson('/api/v1/daily-records?limit=101')
            ->assertStatus(422);
    }

    public function test_from_and_to_filter_by_business_date(): void
    {
        $f = $this->seedDaily(3);

        $res = $this->actingAs($f['operator'])
            ->getJson('/api/v1/daily-records?from=2026-06-02&to=2026-06-03');

        $res->assertStatus(200);
        $res->assertJsonCount(2, 'data');
        $dates = array_column($res->json('data'), 'business_date');
        sort($dates);
        $this->assertSame(['2026-06-02', '2026-06-03'], $dates);
    }
}
