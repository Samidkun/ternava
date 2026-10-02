<?php

declare(strict_types=1);

namespace App\Flocks;

use App\Contracts\Dto\Ack;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use App\Support\MutationExecutor;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class CageService
{
    /**
     * @param  array<string, mixed>  $query
     * @return array<int, array<string, mixed>>
     */
    public function list(ActorScope $actor, array $query = []): array
    {
        $q = DB::table('cages')->where('farm_id', $actor->farmId);

        if ($actor->isOperator()) {
            $q->whereIn('id', $actor->cageIds);
        }

        if (isset($query['active'])) {
            $q->where('active', filter_var($query['active'], FILTER_VALIDATE_BOOLEAN));
        }

        return $q->orderBy('code')->get()->map(fn ($r) => (array) $r)->toArray();
    }

    /**
     * @return array<string, mixed>
     */
    public function get(ActorScope $actor, string $id): array
    {
        if ($actor->isOperator() && ! $actor->canAccessCage($id)) {
            throw new NotFoundHttpException('Kandang tidak ditemukan.');
        }

        $cage = DB::table('cages')
            ->where('id', $id)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $cage) {
            throw new NotFoundHttpException('Kandang tidak ditemukan.');
        }

        return (array) $cage;
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
            '/api/v1/cages',
            $input,
            function () use ($actor) {
                if (! $actor->isOwner() && ! $actor->isAdmin()) {
                    throw new AccessDeniedHttpException('Hanya pengelola yang dapat membuat kandang baru.');
                }
            },
            function () use ($actor, $input) {
                $code = trim((string) $input['code']);
                $exists = DB::table('cages')
                    ->where('farm_id', $actor->farmId)
                    ->whereRaw('lower(code) = ?', [strtolower($code)])
                    ->exists();

                if ($exists) {
                    throw new ConflictHttpException("Kode kandang '{$code}' sudah digunakan di peternakan ini.");
                }

                $id = (string) Str::uuid();
                $cageData = [
                    'id' => $id,
                    'farm_id' => $actor->farmId,
                    'code' => $code,
                    'name' => trim((string) $input['name']),
                    'description' => $input['description'] ?? null,
                    'active' => true,
                    'version' => 1,
                    'updated_at' => now(),
                ];

                DB::table('cages')->insert($cageData);

                ChangeWriter::append(
                    $actor,
                    'cage',
                    $id,
                    'upsert',
                    $cageData
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
            "/api/v1/cages/{$id}",
            $input,
            function () use ($actor) {
                if (! $actor->isOwner() && ! $actor->isAdmin()) {
                    throw new AccessDeniedHttpException('Hanya pengelola yang dapat mengubah data kandang.');
                }
            },
            function () use ($actor, $id, $input) {
                $cage = DB::table('cages')
                    ->where('id', $id)
                    ->where('farm_id', $actor->farmId)
                    ->first();

                if (! $cage) {
                    throw new NotFoundHttpException('Kandang tidak ditemukan.');
                }

                $newVersion = (int) $cage->version + 1;
                $updateData = [
                    'name' => isset($input['name']) ? trim((string) $input['name']) : $cage->name,
                    'description' => array_key_exists('description', $input) ? $input['description'] : $cage->description,
                    'active' => isset($input['active']) ? (bool) $input['active'] : $cage->active,
                    'version' => $newVersion,
                    'updated_at' => now(),
                ];

                DB::table('cages')->where('id', $id)->update($updateData);

                ChangeWriter::append(
                    $actor,
                    'cage',
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
