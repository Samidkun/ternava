<?php

namespace Tests\Feature;

use App\Contracts\Dto\DailyInput;
use Tests\Support\Scenario;
use Tests\TestCase;

class ContractTest extends TestCase
{
    public function test_wire_quantity_rejects_float(): void
    {
        $f = Scenario::layerFarm();
        $response = $this->actingAs($f['operator'])->postJson(
            '/api/v1/daily-records',
            array_merge($f['daily'], ['feed_kg' => 12.5])
        );

        $response->assertStatus(422);
    }

    public function test_wire_quantity_accepts_valid_two_decimal_string(): void
    {
        $f = Scenario::layerFarm();
        $response = $this->actingAs($f['operator'])->postJson(
            '/api/v1/daily-records',
            array_merge($f['daily'], ['feed_kg' => '12.50'])
        );

        $response->assertStatus(200);
    }

    public function test_php_dto_round_trip(): void
    {
        $payload = [
            'cage_id' => 'cage-1',
            'flock_id' => 'flock-1',
            'date' => '2026-10-01',
            'eggs_count' => 85,
            'damaged_eggs_count' => 2,
            'feed_kg' => '12.50',
            'mortality_count' => 0,
        ];

        $dto = DailyInput::fromArray($payload);
        $this->assertSame($payload, $dto->toArray());
    }
}
