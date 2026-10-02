<?php

declare(strict_types=1);

namespace App\Support;

use App\Contracts\Dto\Ack;
use Closure;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

final class MutationExecutor
{
    /**
     * Execute a mutation with authorization, idempotency receipt check, and atomic commit.
     *
     * @param  array<string, mixed>  $payload
     */
    public static function run(
        ActorScope $actor,
        string $key,
        string $method,
        string $path,
        array $payload,
        Closure $authorize,
        Closure $write
    ): Ack {
        // 1. Authorize before lookup/replay
        $authorize();

        $hash = CanonicalJson::hash($method, $path, $payload);

        // 2. Check if receipt already exists
        $existing = DB::table('idempotency_receipts')
            ->where('farm_id', $actor->farmId)
            ->where('actor_id', $actor->actorId)
            ->where('operation_id', $key)
            ->first();

        if ($existing) {
            if ($existing->request_hash !== $hash) {
                throw new ConflictHttpException('Idempotency key reused with different request payload');
            }

            /** @var array<string, mixed> $rawAck */
            $rawAck = json_decode((string) $existing->ack, true);

            return Ack::fromArray($rawAck);
        }

        // 3. Execute write in transaction
        try {
            return DB::transaction(function () use ($actor, $key, $method, $path, $hash, $write) {
                /** @var Ack $ack */
                $ack = $write();

                DB::table('idempotency_receipts')->insert([
                    'id' => (string) Str::uuid(),
                    'farm_id' => $actor->farmId,
                    'actor_id' => $actor->actorId,
                    'operation_id' => $key,
                    'request_hash' => $hash,
                    'method' => strtoupper($method),
                    'path' => $path,
                    'ack' => json_encode($ack->toArray()),
                    'accepted_at' => now(),
                ]);

                return $ack;
            }, 3);
        } catch (\Throwable $e) {
            // A concurrent request carrying the SAME key may have committed
            // between our receipt lookup (step 2) and now. If its receipt is
            // visible, this request is a replay: return the ORIGINAL ACK
            // rather than leaking the unique-constraint / business conflict
            // that the race produced. (AC-27: replays always yield the ACK.)
            $existing = DB::table('idempotency_receipts')
                ->where('farm_id', $actor->farmId)
                ->where('actor_id', $actor->actorId)
                ->where('operation_id', $key)
                ->first();

            if ($existing !== null && $existing->request_hash === $hash) {
                /** @var array<string, mixed> $rawAck */
                $rawAck = json_decode((string) $existing->ack, true);

                return Ack::fromArray($rawAck);
            }

            throw $e;
        }
    }
}
