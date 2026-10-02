<?php

namespace Tests\Feature;

use Tests\TestCase;

class HealthTest extends TestCase
{
    public function test_liveness_does_not_need_database(): void
    {
        $response = $this->getJson('/health/live');

        $response->assertOk()
            ->assertJsonPath('data.status', 'ok')
            ->assertJsonStructure([
                'data' => [
                    'status',
                    'checked_at',
                ],
            ]);
    }

    public function test_readiness_checks_system(): void
    {
        $response = $this->getJson('/health/ready');

        $response->assertOk()
            ->assertJsonPath('data.status', 'ok')
            ->assertJsonStructure([
                'data' => [
                    'status',
                    'checked_at',
                ],
            ]);
    }
}
