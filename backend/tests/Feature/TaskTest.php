<?php

namespace Tests\Feature;

use App\Tasks\MaterializeRuns;
use DateTimeImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\Scenario;
use Tests\TestCase;

class TaskTest extends TestCase
{
    use RefreshDatabase;

    /** @var array<string, mixed> */
    private array $f;

    protected function setUp(): void
    {
        parent::setUp();
        $this->f = Scenario::persist(Scenario::layerFarm());
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function template(array $overrides = []): array
    {
        return Scenario::weeklyTemplate($this->f, $overrides);
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    private function createTemplate(array $payload): TestResponse
    {
        return $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson('/api/v1/task-templates', $payload);
    }

    public function test_scheduler_twice_has_one_occurrence(): void
    {
        $this->createTemplate($this->template())->assertOk();

        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));
        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));

        $this->assertDatabaseCount('task_runs', 1);
    }

    public function test_daily_template_materializes_seven_day_window(): void
    {
        $this->createTemplate($this->template(['recurrence' => 'daily']))->assertOk();

        $created = app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));

        $this->assertSame(7, $created);
        $this->assertDatabaseCount('task_runs', 7);
    }

    public function test_once_template_creates_single_occurrence(): void
    {
        $this->createTemplate($this->template(['recurrence' => 'once']))->assertOk();

        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));
        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));

        $this->assertDatabaseCount('task_runs', 1);
    }

    public function test_checklist_is_literal_and_capped(): void
    {
        $lines = [];
        for ($i = 1; $i <= 25; $i++) {
            $lines[] = "Langkah $i";
        }
        $this->createTemplate($this->template(['sop' => implode("\n", $lines)]))->assertOk();

        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));

        $run = DB::table('task_runs')->first();
        $snapshot = json_decode((string) $run->snapshot, true);

        $this->assertCount(20, $snapshot['checklist_items']);
        $this->assertSame('Langkah 1', $snapshot['checklist_items'][0]['label']);
    }

    public function test_unassigned_or_unauthorized_assignee_rejected(): void
    {
        $payload = $this->template();
        $payload['assignee_id'] = (string) str()->uuid(); // not a member

        $this->createTemplate($payload)->assertStatus(422);
        $this->assertDatabaseCount('task_templates', 0);
    }

    public function test_note_result_does_not_complete_run(): void
    {
        $this->createTemplate($this->template())->assertOk();
        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));
        $run = DB::table('task_runs')->first();

        $res = $this->actingAs($this->f['operator'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/task-runs/{$run->id}/results", [
                'id' => (string) str()->uuid(),
                'base_version' => 1,
                'status' => 'note',
                'notes' => 'Kandang masih lembap',
                'checklist_values' => [],
            ]);

        $res->assertOk();
        $this->assertDatabaseHas('task_runs', ['id' => $run->id, 'status' => 'open']);
    }

    public function test_completed_result_marks_run_completed(): void
    {
        $this->createTemplate($this->template())->assertOk();
        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));
        $run = DB::table('task_runs')->first();

        $this->actingAs($this->f['operator'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/task-runs/{$run->id}/results", [
                'id' => (string) str()->uuid(),
                'base_version' => 1,
                'status' => 'completed',
                'notes' => null,
                'checklist_values' => [],
            ])->assertOk();

        $this->assertDatabaseHas('task_runs', ['id' => $run->id, 'status' => 'completed']);
    }

    public function test_checking_one_item_does_not_auto_check_others(): void
    {
        $this->createTemplate($this->template())->assertOk();
        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));
        $run = DB::table('task_runs')->first();
        $snapshot = json_decode((string) $run->snapshot, true);
        $first = $snapshot['checklist_items'][0]['id'];
        $second = $snapshot['checklist_items'][1]['id'];

        $this->actingAs($this->f['operator'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/task-runs/{$run->id}/results", [
                'id' => (string) str()->uuid(),
                'base_version' => 1,
                'status' => 'note',
                'notes' => 'Sebagian',
                'checklist_values' => [
                    ['id' => $first, 'checked' => true],
                    ['id' => $second, 'checked' => false],
                ],
            ])->assertOk();

        $result = DB::table('task_results')->first();
        $values = json_decode((string) $result->checklist_values, true);
        $this->assertTrue($values[0]['checked']);
        $this->assertFalse($values[1]['checked']);
    }

    public function test_stale_base_version_returns_409(): void
    {
        $this->createTemplate($this->template())->assertOk();
        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));
        $run = DB::table('task_runs')->first();

        $this->actingAs($this->f['operator'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/task-runs/{$run->id}/results", [
                'id' => (string) str()->uuid(),
                'base_version' => 99,
                'status' => 'completed',
                'notes' => null,
                'checklist_values' => [],
            ])->assertStatus(409);
    }

    public function test_result_on_cancelled_run_returns_409(): void
    {
        $this->createTemplate($this->template())->assertOk();
        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));
        $run = DB::table('task_runs')->first();

        DB::table('task_runs')->where('id', $run->id)->update(['status' => 'cancelled']);

        $this->actingAs($this->f['operator'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/task-runs/{$run->id}/results", [
                'id' => (string) str()->uuid(),
                'base_version' => 1,
                'status' => 'completed',
                'notes' => null,
                'checklist_values' => [],
            ])->assertStatus(409);
    }

    public function test_result_replay_is_idempotent(): void
    {
        $this->createTemplate($this->template())->assertOk();
        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));
        $run = DB::table('task_runs')->first();

        $key = (string) str()->uuid();
        $payload = [
            'id' => (string) str()->uuid(),
            'base_version' => 1,
            'status' => 'completed',
            'notes' => null,
            'checklist_values' => [],
        ];

        $this->actingAs($this->f['operator'])
            ->withHeader('Idempotency-Key', $key)
            ->postJson("/api/v1/task-runs/{$run->id}/results", $payload)
            ->assertOk();

        $this->actingAs($this->f['operator'])
            ->withHeader('Idempotency-Key', $key)
            ->postJson("/api/v1/task-runs/{$run->id}/results", $payload)
            ->assertOk();

        $this->assertDatabaseCount('task_results', 1);
    }

    public function test_no_generated_medical_dosage_fields(): void
    {
        $sop = "Periksa suhu kandang\nCatat mortalitas";
        $this->createTemplate($this->template(['sop' => $sop]))->assertOk();

        app(MaterializeRuns::class)->handle($this->f['farm_id'], new DateTimeImmutable('today'));
        $run = DB::table('task_runs')->first();
        $snapshot = json_decode((string) $run->snapshot, true);

        $this->assertSame($sop, $snapshot['sop']);
        $this->assertArrayNotHasKey('dosage', $snapshot);
        $this->assertArrayNotHasKey('diagnosis', $snapshot);
    }
}
