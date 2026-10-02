<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\Support\Scenario;
use Tests\TestCase;

class IncidentTest extends TestCase
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
     */
    private function incidentInput(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) str()->uuid(),
            'cage_id' => $this->f['cage']['id'],
            'flock_id' => $this->f['flock']['id'],
            'observed_at' => now()->toIso8601String(),
            'observation' => 'Ayam terlihat lemas di blok A3',
            'attention' => 'priority',
            'source_daily_record_id' => null,
        ], $overrides);
    }

    private function createIncident(array $payload): TestResponse
    {
        return $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson('/api/v1/incidents', $payload);
    }

    public function test_created_incident_is_open_version_one(): void
    {
        $this->createIncident($this->incidentInput())->assertStatus(201);

        $row = DB::table('incidents')->first();
        $this->assertSame('open', $row->status);
        $this->assertSame(1, (int) $row->version);
    }

    public function test_closed_incident_cannot_be_changed(): void
    {
        $incident = Scenario::closedIncident($this->f);

        $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson('/api/v1/incidents/'.$incident->id.'/actions', Scenario::action($incident))
            ->assertStatus(409);
    }

    public function test_assignment_updates_version_and_records_actor(): void
    {
        $this->createIncident($this->incidentInput())->assertStatus(201);
        $incident = DB::table('incidents')->first();

        $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/incidents/{$incident->id}/assignment", [
                'base_version' => 1,
                'assignee_id' => $this->f['operator']->id,
            ])
            ->assertOk();

        $this->assertDatabaseHas('incidents', [
            'id' => $incident->id,
            'assignee_id' => $this->f['operator']->id,
            'version' => 2,
        ]);

        $this->assertDatabaseHas('incident_actions', [
            'incident_id' => $incident->id,
            'actor_id' => $this->f['owner']->id,
            'action_kind' => 'assign',
        ]);
    }

    public function test_closing_without_notes_is_rejected(): void
    {
        $this->createIncident($this->incidentInput())->assertStatus(201);
        $incident = DB::table('incidents')->first();

        $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/incidents/{$incident->id}/actions", [
                'id' => (string) str()->uuid(),
                'base_version' => 1,
                'notes' => '',
                'status' => 'closed',
            ])
            ->assertStatus(422);

        $this->assertDatabaseHas('incidents', ['id' => $incident->id, 'status' => 'open']);
    }

    public function test_action_advances_status_and_histori(): void
    {
        $this->createIncident($this->incidentInput())->assertStatus(201);
        $incident = DB::table('incidents')->first();

        $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/incidents/{$incident->id}/actions", [
                'id' => (string) str()->uuid(),
                'base_version' => 1,
                'notes' => 'Sudah dipisahkan dari blok lain',
                'status' => 'in_progress',
            ])
            ->assertStatus(201);

        $this->assertDatabaseHas('incidents', ['id' => $incident->id, 'status' => 'in_progress', 'version' => 2]);
        $this->assertDatabaseHas('incident_actions', ['incident_id' => $incident->id, 'status' => 'in_progress']);
    }

    public function test_stale_base_version_returns_409(): void
    {
        $this->createIncident($this->incidentInput())->assertStatus(201);
        $incident = DB::table('incidents')->first();

        $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/incidents/{$incident->id}/actions", [
                'id' => (string) str()->uuid(),
                'base_version' => 99,
                'notes' => 'Aksi basi',
                'status' => 'in_progress',
            ])
            ->assertStatus(409);
    }

    public function test_operator_cannot_act_on_unassigned_incident(): void
    {
        $this->createIncident($this->incidentInput())->assertStatus(201);
        $incident = DB::table('incidents')->first();

        $this->actingAs($this->f['operator'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/incidents/{$incident->id}/actions", [
                'id' => (string) str()->uuid(),
                'base_version' => 1,
                'notes' => 'Coba-coba',
                'status' => 'in_progress',
            ])
            ->assertStatus(403);
    }

    public function test_operator_cannot_assign(): void
    {
        $this->createIncident($this->incidentInput())->assertStatus(201);
        $incident = DB::table('incidents')->first();

        $this->actingAs($this->f['operator'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/incidents/{$incident->id}/assignment", [
                'base_version' => 1,
                'assignee_id' => $this->f['operator']->id,
            ])
            ->assertStatus(403);
    }

    public function test_source_daily_record_must_be_accepted_in_same_farm(): void
    {
        $this->createIncident($this->incidentInput([
            'source_daily_record_id' => (string) str()->uuid(),
        ]))->assertStatus(422);
    }

    public function test_foreign_cage_is_rejected(): void
    {
        $this->createIncident($this->incidentInput([
            'cage_id' => (string) str()->uuid(),
        ]))->assertStatus(422);
    }

    public function test_observation_text_is_accepted_without_photo(): void
    {
        $this->createIncident($this->incidentInput([
            'observation' => 'Nafsu makan turun, tidak ada foto',
        ]))->assertStatus(201);

        $this->assertDatabaseCount('attachments', 0);
    }

    public function test_no_medical_recommendation_fields(): void
    {
        $this->createIncident($this->incidentInput())->assertStatus(201);

        $row = DB::table('incidents')->first();
        $columns = array_keys((array) $row);
        $this->assertNotContains('diagnosis', $columns);
        $this->assertNotContains('dosage', $columns);
        $this->assertNotContains('prescription', $columns);
    }

    public function test_create_is_idempotent(): void
    {
        $key = (string) str()->uuid();
        $payload = $this->incidentInput();

        $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/incidents', $payload)
            ->assertStatus(201);

        $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/incidents', $payload)
            ->assertStatus(201);

        $this->assertDatabaseCount('incidents', 1);
    }

    public function test_list_actions_returns_histori_ordered(): void
    {
        $this->createIncident($this->incidentInput())->assertStatus(201);
        $incident = DB::table('incidents')->first();

        $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/incidents/{$incident->id}/actions", [
                'id' => (string) str()->uuid(),
                'base_version' => 1,
                'notes' => 'Tindakan pertama',
                'status' => 'in_progress',
            ])->assertStatus(201);

        $res = $this->actingAs($this->f['owner'])
            ->getJson("/api/v1/incidents/{$incident->id}/actions")
            ->assertOk();

        $res->assertJsonCount(1, 'data');
    }
}
