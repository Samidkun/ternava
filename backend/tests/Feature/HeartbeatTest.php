<?php

declare(strict_types=1);

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\Support\Scenario;
use Tests\TestCase;

/**
 * AC-45: the system exposes metrics/status that distinguish API, queue, backup
 * and push failures. These tests prove the heartbeat writer:
 *  - writes one machine-readable document per role (worker != scheduler),
 *  - reports queue age / failed jobs / push backlog as separate numbers,
 *  - keeps FCM/push degradation in its own field so it never masks the API,
 *  - never leaks a secret into the heartbeat document.
 */
class HeartbeatTest extends TestCase
{
    use RefreshDatabase;

    /** @var array<string, mixed> */
    private array $f;

    protected function setUp(): void
    {
        parent::setUp();
        $this->f = Scenario::persist(Scenario::layerFarm());
        Storage::fake('local');
    }

    public function test_worker_heartbeat_writes_json_document(): void
    {
        $this->artisan('ternava:heartbeat', ['--role' => 'worker'])->assertExitCode(0);

        Storage::disk('local')->assertExists('heartbeats/worker.json');

        $doc = json_decode(Storage::disk('local')->get('heartbeats/worker.json'), true);

        $this->assertSame('worker', $doc['role']);
        $this->assertArrayHasKey('at', $doc);
        $this->assertArrayHasKey('metrics', $doc);
        $this->assertArrayHasKey('queue_oldest_seconds', $doc['metrics']);
        $this->assertArrayHasKey('failed_jobs', $doc['metrics']);
    }

    public function test_scheduler_and_worker_are_monitored_separately(): void
    {
        $this->artisan('ternava:heartbeat', ['--role' => 'worker'])->assertExitCode(0);
        $this->artisan('ternava:heartbeat', ['--role' => 'scheduler'])->assertExitCode(0);

        Storage::disk('local')->assertExists('heartbeats/worker.json');
        Storage::disk('local')->assertExists('heartbeats/scheduler.json');
    }

    public function test_invalid_role_is_rejected(): void
    {
        $this->artisan('ternava:heartbeat', ['--role' => 'nonsense'])->assertExitCode(1);
    }

    public function test_metrics_count_queued_and_failed_jobs_separately(): void
    {
        DB::table('jobs')->insert([
            'queue' => 'default', 'payload' => '{}', 'attempts' => 0,
            'reserved_at' => null, 'available_at' => now()->getTimestamp(),
            'created_at' => now()->subMinutes(10)->getTimestamp(),
        ]);
        DB::table('failed_jobs')->insert([
            'uuid' => (string) str()->uuid(), 'connection' => 'database',
            'queue' => 'default', 'payload' => '{}', 'exception' => 'boom',
            'failed_at' => now(),
        ]);

        $this->artisan('ternava:heartbeat', ['--role' => 'worker', '--json' => true])
            ->expectsOutputToContain('queue_oldest_seconds')
            ->assertExitCode(0);

        $doc = json_decode(Storage::disk('local')->get('heartbeats/worker.json'), true);
        $this->assertSame(1, $doc['metrics']['queue_depth']);
        $this->assertSame(1, $doc['metrics']['failed_jobs']);
        $this->assertGreaterThan(0, $doc['metrics']['queue_oldest_seconds']);
    }

    public function test_push_degradation_is_a_separate_signal_not_api_failure(): void
    {
        // An undelivered push event must show up in the push metric only.
        DB::table('notification_outbox')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $this->f['farm_id'],
            'event_kind' => 'incident',
            'resource_id' => (string) str()->uuid(),
            'payload' => '{}',
            'attempts' => 0,
            'processed_at' => null,
            'created_at' => now(),
        ]);

        $this->artisan('ternava:heartbeat', ['--role' => 'worker'])->assertExitCode(0);

        $doc = json_decode(Storage::disk('local')->get('heartbeats/worker.json'), true);
        $this->assertSame(1, $doc['metrics']['push_undelivered']);
        $this->assertArrayHasKey('push_degraded_devices', $doc['metrics']);
    }

    public function test_heartbeat_document_contains_no_secret_values(): void
    {
        config(['database.connections.pgsql.password' => 'super-secret-db-pass']);

        $this->artisan('ternava:heartbeat', ['--role' => 'worker'])->assertExitCode(0);

        $raw = Storage::disk('local')->get('heartbeats/worker.json');
        $this->assertStringNotContainsString('super-secret-db-pass', $raw);
    }
}
