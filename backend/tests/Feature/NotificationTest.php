<?php

namespace Tests\Feature;

use App\Notifications\DeliverEvent;
use App\Notifications\PushService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\Scenario;
use Tests\TestCase;

class NotificationTest extends TestCase
{
    use RefreshDatabase;

    /** @var array<string, mixed> */
    private array $f;

    protected function setUp(): void
    {
        parent::setUp();
        $this->f = Scenario::persist(Scenario::layerFarm());
    }

    public function test_push_failure_keeps_one_inbox_item(): void
    {
        $event = Scenario::incidentEvent($this->f);
        Scenario::failFcm();

        app(DeliverEvent::class)->handle($event->id);
        app(DeliverEvent::class)->handle($event->id);

        $this->assertDatabaseCount('inbox_items', 1);
    }

    public function test_inbox_is_unique_per_event_and_user(): void
    {
        $event = Scenario::incidentEvent($this->f);

        app(DeliverEvent::class)->handle($event->id);
        app(DeliverEvent::class)->handle($event->id);
        app(DeliverEvent::class)->handle($event->id);

        $this->assertDatabaseCount('inbox_items', 1);
    }

    public function test_push_payload_is_generic_and_has_no_observation(): void
    {
        $event = Scenario::incidentEvent($this->f, 'Ayam terlihat lemas di blok A3');
        $push = app(PushService::class);

        $payload = $push->buildPayload($event->id);

        // The push only carries generic identifiers, never the observation text.
        $encoded = json_encode($payload);
        $this->assertStringNotContainsString('lemas', $encoded);
        $this->assertArrayHasKey('event_id', $payload);
        $this->assertArrayHasKey('kind', $payload);
        $this->assertArrayNotHasKey('observation', $payload);
    }

    public function test_inbox_persisted_before_push_is_attempted(): void
    {
        $event = Scenario::incidentEvent($this->f);
        Scenario::failFcm();

        app(DeliverEvent::class)->handle($event->id);

        // Even with a failed push, the durable inbox item exists.
        $this->assertDatabaseCount('inbox_items', 1);
        $this->assertNotNull(
            DB::table('notification_outbox')->where('id', $event->id)->first()
        );
    }

    public function test_push_failure_does_not_rollback_business_state(): void
    {
        $incident = Scenario::closedIncident($this->f);
        $event = Scenario::incidentEvent($this->f);
        Scenario::failFcm();

        app(DeliverEvent::class)->handle($event->id);

        // The underlying incident row is untouched by the failed push.
        $this->assertDatabaseHas('incidents', [
            'id' => $incident->id,
            'status' => 'closed',
        ]);
    }

    public function test_delivery_is_idempotent_across_retries(): void
    {
        $event = Scenario::incidentEvent($this->f);
        Scenario::failFcm();

        app(DeliverEvent::class)->handle($event->id);
        app(DeliverEvent::class)->handle($event->id);
        app(DeliverEvent::class)->handle($event->id);

        $this->assertDatabaseCount('inbox_items', 1);
        $row = DB::table('inbox_items')->first();
        $this->assertNotNull($row);
    }

    public function test_list_inbox_is_scoped_to_current_user(): void
    {
        $event = Scenario::incidentEvent($this->f);
        app(DeliverEvent::class)->handle($event->id);

        $res = $this->actingAs($this->f['owner'])
            ->getJson('/api/v1/inbox')
            ->assertOk();

        $res->assertJsonStructure(['data']);
    }

    public function test_other_user_cannot_read_foreign_inbox_item(): void
    {
        $event = Scenario::incidentEvent($this->f);
        app(DeliverEvent::class)->handle($event->id);
        $item = DB::table('inbox_items')->first();

        $this->actingAs($this->f['other'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/inbox/{$item->id}/read")
            ->assertNotFound();
    }

    public function test_read_inbox_marks_read_once(): void
    {
        $event = Scenario::incidentEvent($this->f);
        app(DeliverEvent::class)->handle($event->id);
        $item = DB::table('inbox_items')->first();

        $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->postJson("/api/v1/inbox/{$item->id}/read")
            ->assertOk();

        $updated = DB::table('inbox_items')->where('id', $item->id)->first();
        $this->assertNotNull($updated->read_at);
    }

    public function test_register_push_device_encrypts_token(): void
    {
        $deviceId = (string) str()->uuid();
        $token = 'fcm-token-super-secret-value';

        $this->actingAs($this->f['owner'])
            ->putJson('/api/v1/push-devices', [
                'device_id' => $deviceId,
                'fcm_token' => $token,
                'enabled' => true,
            ])
            ->assertOk();

        $row = DB::table('push_devices')->where('device_id', $deviceId)->first();
        $this->assertNotNull($row);
        // The token must not be stored in plaintext.
        $this->assertNotSame($token, $row->fcm_token_encrypted);
    }

    public function test_register_push_is_idempotent_per_device(): void
    {
        $deviceId = (string) str()->uuid();
        $body = [
            'device_id' => $deviceId,
            'fcm_token' => 'token-abc',
            'enabled' => true,
        ];

        $this->actingAs($this->f['owner'])->putJson('/api/v1/push-devices', $body)->assertOk();
        $this->actingAs($this->f['owner'])->putJson('/api/v1/push-devices', $body)->assertOk();

        $this->assertDatabaseCount('push_devices', 1);
    }

    public function test_unregister_push_device(): void
    {
        $deviceId = (string) str()->uuid();
        $this->actingAs($this->f['owner'])->putJson('/api/v1/push-devices', [
            'device_id' => $deviceId,
            'fcm_token' => 'token-abc',
            'enabled' => true,
        ])->assertOk();

        $this->actingAs($this->f['owner'])
            ->deleteJson("/api/v1/push-devices/{$deviceId}")
            ->assertNoContent();

        $this->assertDatabaseMissing('push_devices', ['device_id' => $deviceId]);
    }
}
