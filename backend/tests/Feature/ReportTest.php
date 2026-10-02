<?php

namespace Tests\Feature;

use App\Insights\CsvWriter;
use App\Insights\ReportService;
use App\Support\ActorScope;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Tests\Support\Scenario;
use Tests\TestCase;

class ReportTest extends TestCase
{
    use RefreshDatabase;

    /** @var array<string, mixed> */
    private array $f;

    protected function setUp(): void
    {
        parent::setUp();
        $this->f = Scenario::persist(Scenario::layerFarm());
    }

    private function scopeOwner(): ActorScope
    {
        return new ActorScope(
            actorId: (string) $this->f['owner']->id,
            farmId: (string) $this->f['farm_id'],
            role: 'owner'
        );
    }

    public function test_missing_is_not_zero_in_report(): void
    {
        $today = now()->format('Y-m-d');
        $r = app(ReportService::class)->operations($this->scopeOwner(), $today, $today);

        $this->assertNull($r['eggs_count']);
        $this->assertSame(0, $r['accepted_records']);
        $this->assertSame(1, $r['expected_records']);
    }

    public function test_accepted_zero_is_distinct_from_missing(): void
    {
        $today = now()->format('Y-m-d');
        DB::table('daily_records')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $this->f['farm_id'],
            'flock_id' => $this->f['flock']['id'],
            'business_date' => $today,
            'feed_type_id' => $this->f['feed']['id'],
            'feed_kg' => '0.00',
            'eggs_count' => 0,
            'mortality_count' => 0,
            'condition' => 'normal',
            'version' => 1,
            'recorded_by' => $this->f['owner']->id,
            'accepted_at' => now(),
            'updated_at' => now(),
        ]);

        $r = app(ReportService::class)->operations($this->scopeOwner(), $today, $today);

        $this->assertSame(0, $r['eggs_count']);
        $this->assertSame('0.00', $r['feed_kg']);
        $this->assertSame(1, $r['accepted_records']);
    }

    public function test_period_capped_at_183_days(): void
    {
        $from = now()->subDays(200)->format('Y-m-d');
        $to = now()->format('Y-m-d');

        $this->expectException(ValidationException::class);
        app(ReportService::class)->operations($this->scopeOwner(), $from, $to);
    }

    public function test_to_before_from_is_rejected(): void
    {
        $this->expectException(ValidationException::class);
        app(ReportService::class)->operations(
            $this->scopeOwner(),
            now()->format('Y-m-d'),
            now()->subDay()->format('Y-m-d')
        );
    }

    public function test_report_includes_timezone_and_as_of(): void
    {
        $today = now()->format('Y-m-d');
        $r = app(ReportService::class)->operations($this->scopeOwner(), $today, $today);

        $this->assertSame('Asia/Jakarta', $r['timezone']);
        $this->assertArrayHasKey('as_of', $r);
    }

    public function test_expected_includes_historical_finished_flock(): void
    {
        // A flock finished mid-period is still expected for its active days.
        DB::table('flocks')
            ->where('id', $this->f['flock']['id'])
            ->update(['finished_on' => now()->format('Y-m-d')]);

        $today = now()->format('Y-m-d');
        $r = app(ReportService::class)->operations($this->scopeOwner(), $today, $today);

        $this->assertSame(1, $r['expected_records']);
    }

    public function test_missing_rows_are_marked_missing(): void
    {
        $today = now()->format('Y-m-d');
        $r = app(ReportService::class)->operations($this->scopeOwner(), $today, $today);

        $this->assertCount(1, $r['rows']);
        $this->assertSame('missing', $r['rows'][0]['record_state']);
        $this->assertNull($r['rows'][0]['eggs_count']);
    }

    public function test_csv_escapes_formula_injection(): void
    {
        $csv = app(CsvWriter::class);
        $out = fopen('php://temp', 'r+');

        $csv->write([
            'from' => '2026-10-01',
            'to' => '2026-10-01',
            'timezone' => 'Asia/Jakarta',
            'as_of' => now()->toIso8601String(),
            'expected_records' => 1,
            'accepted_records' => 1,
            'eggs_count' => 5,
            'feed_kg' => '1.00',
            'rows' => [[
                'business_date' => '2026-10-01',
                'cage_id' => 'cage-1',
                'flock_id' => 'flock-1',
                'record_state' => 'accepted',
                'eggs_count' => 5,
                'feed_kg' => '1.00',
                'mortality_count' => 0,
                'condition' => '=HYPERLINK("http://evil")',
            ]],
        ], $out);

        rewind($out);
        $content = stream_get_contents($out);
        fclose($out);

        // A leading '=' must be neutralized with a quote prefix.
        $this->assertStringContainsString("'=HYPERLINK", $content);
        // UTF-8 BOM for spreadsheet compatibility.
        $this->assertStringStartsWith("\xEF\xBB\xBF", $content);
    }

    public function test_csv_is_rfc4180_quoted(): void
    {
        $csv = app(CsvWriter::class);
        $out = fopen('php://temp', 'r+');

        $csv->write([
            'from' => '2026-10-01',
            'to' => '2026-10-01',
            'timezone' => 'Asia/Jakarta',
            'as_of' => now()->toIso8601String(),
            'expected_records' => 1,
            'accepted_records' => 1,
            'eggs_count' => 5,
            'feed_kg' => '1.00',
            'rows' => [[
                'business_date' => '2026-10-01',
                'cage_id' => 'cage-1',
                'flock_id' => 'flock-1',
                'record_state' => 'accepted',
                'eggs_count' => 5,
                'feed_kg' => '1.00',
                'mortality_count' => 0,
                'condition' => 'nilai, dengan koma',
            ]],
        ], $out);

        rewind($out);
        $content = stream_get_contents($out);
        fclose($out);

        $this->assertStringContainsString('"nilai, dengan koma"', $content);
    }

    public function test_csv_has_no_profit_or_fcr_claim(): void
    {
        $csv = app(CsvWriter::class);
        $out = fopen('php://temp', 'r+');

        $csv->write([
            'from' => '2026-10-01', 'to' => '2026-10-01', 'timezone' => 'Asia/Jakarta',
            'as_of' => now()->toIso8601String(), 'expected_records' => 0,
            'accepted_records' => 0, 'eggs_count' => null, 'feed_kg' => null, 'rows' => [],
        ], $out);

        rewind($out);
        $content = strtolower((string) stream_get_contents($out));
        fclose($out);

        $this->assertStringNotContainsString('profit', $content);
        $this->assertStringNotContainsString('fcr', $content);
    }

    public function test_operator_cannot_read_reports(): void
    {
        $this->actingAs($this->f['operator'])
            ->getJson('/api/v1/dashboard?business_date='.now()->format('Y-m-d'))
            ->assertStatus(403);
    }

    public function test_dashboard_requires_manager_role(): void
    {
        $res = $this->actingAs($this->f['owner'])
            ->getJson('/api/v1/dashboard?business_date='.now()->format('Y-m-d'))
            ->assertOk();

        $res->assertJsonStructure(['data' => ['business_date', 'expected_records', 'accepted_records', 'cages']]);
    }

    public function test_report_reads_are_repeatable(): void
    {
        $today = now()->format('Y-m-d');
        $svc = app(ReportService::class);
        $a = $svc->operations($this->scopeOwner(), $today, $today);
        $b = $svc->operations($this->scopeOwner(), $today, $today);

        $this->assertSame($a['expected_records'], $b['expected_records']);
        $this->assertSame($a['accepted_records'], $b['accepted_records']);
    }
}
