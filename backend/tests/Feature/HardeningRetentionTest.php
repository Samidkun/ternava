<?php

declare(strict_types=1);

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\Support\Scenario;
use Tests\TestCase;

class HardeningRetentionTest extends TestCase
{
    use RefreshDatabase;

    /** @var array<string, mixed> */
    private array $f;

    protected function setUp(): void
    {
        parent::setUp();
        $this->f = Scenario::persist(Scenario::layerFarm());

        foreach (['uploads', 'exports', 'auth'] as $name) {
            RateLimiter::clear($name.':'.$this->f['owner']->id);
            RateLimiter::clear($name.':'.$this->f['operator']->id);
        }
    }

    // ---- AC-46: retention keeps ledger + replayable dedup key --------------

    public function test_old_receipt_still_blocks_duplicate_after_retention(): void
    {
        $f = $this->f;
        $intent = Scenario::acceptedDailyIntent($f, $this);
        Scenario::ageOperationalRows(731);

        $this->artisan('ternava:retention')->assertExitCode(0);

        Scenario::replayIntent($this, $f, $intent)->assertOk();
        $this->assertDatabaseCount('idempotency_receipts', 1);
    }

    public function test_retention_keeps_ledger_rows_inside_business_window(): void
    {
        $f = $this->f;
        Scenario::acceptedDailyIntent($f, $this);
        Scenario::ageOperationalRows(100); // inside the 730d ledger window

        $this->artisan('ternava:retention')->assertExitCode(0);

        $this->assertDatabaseCount('daily_records', 1);
        $this->assertDatabaseCount('feed_entries', 1);
        $this->assertDatabaseCount('idempotency_receipts', 1);
    }

    public function test_retention_appends_deletion_journal_for_expired_rows(): void
    {
        $f = $this->f;
        Scenario::acceptedDailyIntent($f, $this);
        Scenario::ageOperationalRows(100);

        $this->artisan('ternava:retention')->assertExitCode(0);

        // sync_changes outlives the 30d window, so it is purged and journalled.
        $this->assertDatabaseCount('sync_changes', 0);
        $this->assertGreaterThan(
            0,
            DB::table('audit_events')->where('action', 'retention.deletion')->count()
        );
    }

    public function test_retention_purges_expired_photos_without_touching_parent(): void
    {
        $f = $this->f;
        $photo = Scenario::acceptedPhoto($f);
        Scenario::ageOperationalRows(181); // past the 180d photo window

        $this->artisan('ternava:retention')->assertExitCode(0);

        // Photo bytes and their attachment rows expire; the parent business
        // record and the ledger stay intact (no referential break).
        Storage::disk('private')->assertMissing($photo->storage_key);
        $this->assertDatabaseCount('attachments', 0);
        $this->assertDatabaseCount('daily_records', 1);
    }

    public function test_close_farm_journals_closure_and_deactivates_memberships(): void
    {
        $f = $this->f;

        $this->artisan('ternava:close-farm', ['farm' => $f['farm_id']])->assertExitCode(0);

        // Closure exports a snapshot, deactivates access and journals the act;
        // the farm row itself is preserved rather than hard-deleted.
        $this->assertNotEmpty(Storage::disk('private')->files('exports'));
        $this->assertSame(
            0,
            DB::table('memberships')->where('farm_id', $f['farm_id'])->where('active', true)->count()
        );
        $this->assertGreaterThan(
            0,
            DB::table('audit_events')->where('action', 'farm.closure')->count()
        );
        $this->assertDatabaseCount('farms', 2);
    }

    public function test_retention_is_idempotent_across_repeated_runs(): void
    {
        $f = $this->f;
        Scenario::acceptedDailyIntent($f, $this);
        Scenario::ageOperationalRows(100);

        $this->artisan('ternava:retention')->assertExitCode(0);
        $journal = DB::table('audit_events')->where('action', 'retention.deletion')->count();

        $this->artisan('ternava:retention')->assertExitCode(0);

        $this->assertDatabaseCount('daily_records', 1);
        $this->assertSame($journal, DB::table('audit_events')->where('action', 'retention.deletion')->count());
    }

    // ---- AC-41: abuse limits (rate / size / range) -------------------------

    public function test_export_rate_limit_returns_retry_after_without_side_effects(): void
    {
        $f = $this->f;
        $before = DB::table('daily_records')->count();

        $payload = [
            'from' => now()->format('Y-m-d'),
            'to' => now()->format('Y-m-d'),
        ];

        for ($i = 0; $i < 3; $i++) {
            $this->actingAs($f['owner'])
                ->getJson('/api/v1/reports/operations.csv?from='.$payload['from'].'&to='.$payload['to'])
                ->assertOk();
        }

        $throttled = $this->actingAs($f['owner'])
            ->getJson('/api/v1/reports/operations.csv?from='.$payload['from'].'&to='.$payload['to']);

        $throttled->assertStatus(429);
        $throttled->assertHeader('Retry-After');

        $this->assertSame($before, DB::table('daily_records')->count());
    }

    public function test_authenticated_requests_share_a_rate_budget(): void
    {
        $f = $this->f;
        $key = 'auth:'.$f['owner']->id;
        RateLimiter::clear($key);

        // Saturate the authenticated budget, then the next call is throttled.
        for ($i = 0; $i < 120; $i++) {
            RateLimiter::hit($key, 60);
        }

        $this->actingAs($f['owner'])
            ->getJson('/api/v1/farm')
            ->assertStatus(429)
            ->assertHeader('Retry-After');
    }

    public function test_report_range_over_183_days_is_rejected_without_side_effects(): void
    {
        $f = $this->f;
        $before = DB::table('daily_records')->count();

        $this->actingAs($f['owner'])
            ->getJson('/api/v1/reports/operations?from=2026-01-01&to=2026-09-30')
            ->assertStatus(422);

        $this->assertSame($before, DB::table('daily_records')->count());
    }

    public function test_json_body_over_64_kib_is_rejected(): void
    {
        $f = $this->f;

        $res = $this->actingAs($f['owner'])
            ->withHeader('Idempotency-Key', (string) Str::uuid())
            ->call('POST', '/api/v1/daily-records', [], [], [], [
                'CONTENT_TYPE' => 'application/json',
            ], json_encode(array_merge($f['daily'], [
                'notes' => str_repeat('x', 70 * 1024),
            ])));

        $this->assertSame(413, $res->getStatusCode());
    }

    public function test_upload_rate_limit_is_enforced_after_ten_per_minute(): void
    {
        $f = $this->f;
        $key = md5('uploads'.$f['owner']->id);
        RateLimiter::clear($key);

        for ($i = 0; $i < 10; $i++) {
            RateLimiter::hit($key, 60);
        }

        $this->actingAs($f['owner'])
            ->postJson('/api/v1/attachments', [])
            ->assertStatus(429)
            ->assertHeader('Retry-After');
    }
}
