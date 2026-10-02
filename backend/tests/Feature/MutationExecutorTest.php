<?php

namespace Tests\Feature;

use App\Contracts\Dto\Ack;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use App\Support\MutationExecutor;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Tests\TestCase;

class MutationExecutorTest extends TestCase
{
    use RefreshDatabase;

    private ActorScope $actor;

    protected function setUp(): void
    {
        parent::setUp();

        $farmId = (string) str()->uuid();
        $userId = (string) str()->uuid();

        DB::table('farms')->insert([
            'id' => $farmId,
            'name' => 'Farm Mutation Test',
            'location' => 'Malang',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('users')->insert([
            'id' => $userId,
            'username' => 'actor_user',
            'display_name' => 'Actor',
            'password_hash' => 'hash',
            'must_change_password' => false,
            'active' => true,
        ]);

        $this->actor = new ActorScope(
            actorId: $userId,
            farmId: $farmId,
            role: 'owner',
        );
    }

    public function test_replay_has_one_effect_and_original_ack(): void
    {
        $key = (string) str()->uuid();
        $payload = ['amount' => 100, 'item' => 'feed'];
        $sideEffectCount = 0;

        $authorize = fn () => true;
        $write = function () use (&$sideEffectCount) {
            $sideEffectCount++;

            return Ack::fromArray(['status' => 'accepted', 'version' => 1]);
        };

        // First call
        $firstAck = MutationExecutor::run(
            $this->actor,
            $key,
            'POST',
            '/api/v1/feed-entries',
            $payload,
            $authorize,
            $write
        );

        $this->assertSame('accepted', $firstAck->toArray()['status']);
        $this->assertSame(1, $sideEffectCount);
        $this->assertDatabaseCount('idempotency_receipts', 1);

        // Replay with identical key & payload
        $replayAck = MutationExecutor::run(
            $this->actor,
            $key,
            'POST',
            '/api/v1/feed-entries',
            $payload,
            $authorize,
            $write
        );

        $this->assertSame($firstAck->toArray(), $replayAck->toArray());
        // Side effect must NOT execute again
        $this->assertSame(1, $sideEffectCount);
        $this->assertDatabaseCount('idempotency_receipts', 1);
    }

    public function test_replay_with_different_payload_throws_conflict_409(): void
    {
        $key = (string) str()->uuid();
        $authorize = fn () => true;

        MutationExecutor::run(
            $this->actor,
            $key,
            'POST',
            '/api/v1/feed-entries',
            ['amount' => 100],
            $authorize,
            fn () => Ack::fromArray(['status' => 'accepted', 'version' => 1])
        );

        $this->expectException(ConflictHttpException::class);

        // Reusing same key with altered payload
        MutationExecutor::run(
            $this->actor,
            $key,
            'POST',
            '/api/v1/feed-entries',
            ['amount' => 200],
            $authorize,
            fn () => Ack::fromArray(['status' => 'accepted', 'version' => 1])
        );
    }

    public function test_change_writer_monotonic_sequence(): void
    {
        $seq1 = ChangeWriter::append($this->actor, 'cage', (string) str()->uuid(), 'upsert', ['code' => 'K1']);
        $seq2 = ChangeWriter::append($this->actor, 'cage', (string) str()->uuid(), 'upsert', ['code' => 'K2']);

        $this->assertSame(1, $seq1);
        $this->assertSame(2, $seq2);

        $this->assertDatabaseCount('sync_changes', 2);
    }
}
