<?php

declare(strict_types=1);

namespace App\Flocks;

use App\Contracts\Dto\Ack;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use App\Support\MutationExecutor;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class FlockService
{
    /**
     * @param  array<string, mixed>  $query
     * @return array<int, array<string, mixed>>
     */
    public function list(ActorScope $actor, array $query = []): array
    {
        $q = DB::table('flocks')->where('farm_id', $actor->farmId);

        if ($actor->isOperator()) {
            $q->whereIn('cage_id', $actor->cageIds);
        }

        if (isset($query['cage_id'])) {
            $q->where('cage_id', $query['cage_id']);
        }

        if (isset($query['active'])) {
            $isActive = filter_var($query['active'], FILTER_VALIDATE_BOOLEAN);
            if ($isActive) {
                $q->whereNull('finished_on');
            } else {
                $q->whereNotNull('finished_on');
            }
        }

        return $q->orderByDesc('placed_on')->get()->map(fn ($r) => (array) $r)->toArray();
    }

    /**
     * @return array<string, mixed>
     */
    public function get(ActorScope $actor, string $id): array
    {
        $flock = DB::table('flocks')
            ->where('id', $id)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $flock) {
            throw new NotFoundHttpException('Kelompok ayam tidak ditemukan.');
        }

        if ($actor->isOperator() && ! $actor->canAccessCage($flock->cage_id)) {
            throw new NotFoundHttpException('Kelompok ayam tidak ditemukan.');
        }

        return (array) $flock;
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function create(ActorScope $actor, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'POST',
            '/api/v1/flocks',
            $input,
            function () use ($actor) {
                if (! $actor->isOwner() && ! $actor->isAdmin()) {
                    throw new AccessDeniedHttpException('Hanya pengelola yang dapat membuat kelompok ayam.');
                }
            },
            function () use ($actor, $input) {
                $code = trim((string) $input['code']);
                $cageId = (string) $input['cage_id'];

                // 1. Check code uniqueness
                $codeExists = DB::table('flocks')
                    ->where('farm_id', $actor->farmId)
                    ->whereRaw('lower(code) = ?', [strtolower($code)])
                    ->exists();
                if ($codeExists) {
                    throw new ConflictHttpException("Kode kelompok '{$code}' sudah digunakan di peternakan ini.");
                }

                // 2. Check active flock in cage (one_active_flock)
                $activeFlockExists = DB::table('flocks')
                    ->where('cage_id', $cageId)
                    ->whereNull('finished_on')
                    ->exists();
                if ($activeFlockExists) {
                    throw new ConflictHttpException('Kandang ini masih memiliki kelompok ayam aktif yang belum selesai.');
                }

                $id = (string) ($input['id'] ?? Str::uuid());
                $initialPop = (int) $input['initial_population'];
                $flockData = [
                    'id' => $id,
                    'farm_id' => $actor->farmId,
                    'cage_id' => $cageId,
                    'code' => $code,
                    'placed_on' => $input['placed_on'],
                    'finished_on' => $input['finished_on'] ?? null,
                    'initial_population' => $initialPop,
                    'recorded_population' => $initialPop,
                    'version' => 1,
                    'updated_at' => now(),
                ];

                DB::table('flocks')->insert($flockData);

                // Initial population entry in population_entries
                DB::table('population_entries')->insert([
                    'id' => (string) Str::uuid(),
                    'farm_id' => $actor->farmId,
                    'flock_id' => $id,
                    'business_date' => $input['placed_on'],
                    'delta_count' => $initialPop,
                    'reason' => 'Populasi awal kelompok',
                    'accepted_at' => now(),
                ]);

                ChangeWriter::append(
                    $actor,
                    'flock',
                    $id,
                    'upsert',
                    $flockData
                );

                return Ack::fromArray([
                    'status' => 'accepted',
                    'id' => $id,
                    'version' => 1,
                ]);
            }
        );
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function update(ActorScope $actor, string $id, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'PATCH',
            "/api/v1/flocks/{$id}",
            $input,
            function () use ($actor) {
                if (! $actor->isOwner() && ! $actor->isAdmin()) {
                    throw new AccessDeniedHttpException('Hanya pengelola yang dapat mengubah data kelompok.');
                }
            },
            function () use ($actor, $id, $input) {
                $flock = DB::table('flocks')
                    ->where('id', $id)
                    ->where('farm_id', $actor->farmId)
                    ->first();

                if (! $flock) {
                    throw new NotFoundHttpException('Kelompok ayam tidak ditemukan.');
                }

                // If daily records exist, initial_population is immutable!
                $requestedInitial = isset($input['initial_population']) ? (int) $input['initial_population'] : (int) $flock->initial_population;
                if ($requestedInitial !== (int) $flock->initial_population) {
                    if (PopulationProjection::hasDailyRecords($id)) {
                        throw ValidationException::withMessages([
                            'initial_population' => ['Populasi awal tidak dapat diubah setelah ada catatan harian.'],
                        ]);
                    }
                }

                PopulationProjection::assertPrefixes($id, ['initial_population' => $requestedInitial]);

                $newVersion = (int) $flock->version + 1;
                $finishedOn = $flock->finished_on;
                if (isset($input['status']) && $input['status'] === 'finished') {
                    $finishedOn = $input['finished_on'] ?? now()->format('Y-m-d');
                } elseif (isset($input['status']) && $input['status'] === 'active') {
                    $finishedOn = null;
                }

                $updateData = [
                    'code' => isset($input['code']) ? trim((string) $input['code']) : $flock->code,
                    'finished_on' => $finishedOn,
                    'initial_population' => $requestedInitial,
                    'version' => $newVersion,
                    'updated_at' => now(),
                ];

                DB::table('flocks')->where('id', $id)->update($updateData);

                ChangeWriter::append(
                    $actor,
                    'flock',
                    $id,
                    'upsert',
                    $updateData
                );

                return Ack::fromArray([
                    'status' => 'accepted',
                    'id' => $id,
                    'version' => $newVersion,
                ]);
            }
        );
    }
}
