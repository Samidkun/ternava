<?php

declare(strict_types=1);

namespace App\Feed;

use App\Contracts\Dto\Ack;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use App\Support\MutationExecutor;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class FeedService
{
    /**
     * @param  array<string, mixed>  $query
     * @return array<int, array<string, mixed>>
     */
    public function listTypes(ActorScope $actor, array $query = []): array
    {
        $q = DB::table('feed_types')->where('farm_id', $actor->farmId);

        if (isset($query['active'])) {
            $q->where('active', filter_var($query['active'], FILTER_VALIDATE_BOOLEAN));
        }

        return $q->orderBy('code')->get()->map(fn ($r) => (array) $r)->toArray();
    }

    /**
     * @return array<string, mixed>
     */
    public function getType(ActorScope $actor, string $id): array
    {
        $type = DB::table('feed_types')
            ->where('id', $id)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $type) {
            throw new NotFoundHttpException('Jenis pakan tidak ditemukan.');
        }

        return (array) $type;
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function createType(ActorScope $actor, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'POST',
            '/api/v1/feed-types',
            $input,
            function () use ($actor) {
                if (! $actor->isOwner() && ! $actor->isAdmin()) {
                    throw new AccessDeniedHttpException('Hanya pengelola yang dapat menambah jenis pakan.');
                }
            },
            function () use ($actor, $input) {
                $code = trim((string) $input['code']);
                $exists = DB::table('feed_types')
                    ->where('farm_id', $actor->farmId)
                    ->whereRaw('lower(code) = ?', [strtolower($code)])
                    ->exists();

                if ($exists) {
                    throw new ConflictHttpException("Kode jenis pakan '{$code}' sudah digunakan.");
                }

                $id = (string) ($input['id'] ?? Str::uuid());
                $typeData = [
                    'id' => $id,
                    'farm_id' => $actor->farmId,
                    'code' => $code,
                    'name' => trim((string) $input['name']),
                    'minimum_kg' => $input['minimum_kg'] ?? '0.00',
                    'active' => true,
                    'version' => 1,
                    'updated_at' => now(),
                ];

                DB::table('feed_types')->insert($typeData);

                // Initialize balance row
                DB::table('feed_balances')->insert([
                    'id' => (string) Str::uuid(),
                    'farm_id' => $actor->farmId,
                    'feed_type_id' => $id,
                    'quantity_kg' => '0.00',
                    'updated_at' => now(),
                ]);

                ChangeWriter::append(
                    $actor,
                    'feed_type',
                    $id,
                    'upsert',
                    $typeData
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
    public function updateType(ActorScope $actor, string $id, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'PATCH',
            "/api/v1/feed-types/{$id}",
            $input,
            function () use ($actor) {
                if (! $actor->isOwner() && ! $actor->isAdmin()) {
                    throw new AccessDeniedHttpException('Hanya pengelola yang dapat mengubah jenis pakan.');
                }
            },
            function () use ($actor, $id, $input) {
                $type = DB::table('feed_types')
                    ->where('id', $id)
                    ->where('farm_id', $actor->farmId)
                    ->first();

                if (! $type) {
                    throw new NotFoundHttpException('Jenis pakan tidak ditemukan.');
                }

                $newVersion = (int) $type->version + 1;
                $updateData = [
                    'name' => isset($input['name']) ? trim((string) $input['name']) : $type->name,
                    'minimum_kg' => $input['minimum_kg'] ?? $type->minimum_kg,
                    'active' => isset($input['active']) ? (bool) $input['active'] : $type->active,
                    'version' => $newVersion,
                    'updated_at' => now(),
                ];

                DB::table('feed_types')->where('id', $id)->update($updateData);

                ChangeWriter::append(
                    $actor,
                    'feed_type',
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

    /**
     * @return array<int, array<string, mixed>>
     */
    public function listBalances(ActorScope $actor): array
    {
        return DB::table('feed_balances')
            ->join('feed_types', 'feed_balances.feed_type_id', '=', 'feed_types.id')
            ->where('feed_balances.farm_id', $actor->farmId)
            ->select(
                'feed_balances.id',
                'feed_balances.farm_id',
                'feed_balances.feed_type_id',
                'feed_types.code as feed_type_code',
                'feed_types.name as feed_type_name',
                'feed_balances.quantity_kg',
                'feed_balances.updated_at'
            )
            ->get()
            ->map(fn ($r) => (array) $r)
            ->toArray();
    }

    /**
     * @param  array<string, mixed>  $query
     * @return array<int, array<string, mixed>>
     */
    public function listEntries(ActorScope $actor, array $query = []): array
    {
        if ($actor->isOperator()) {
            throw new AccessDeniedHttpException('Operator tidak memiliki izin membaca buku besar mutasi.');
        }

        $q = DB::table('feed_entries')->where('farm_id', $actor->farmId);

        if (isset($query['feed_type_id'])) {
            $q->where('feed_type_id', $query['feed_type_id']);
        }

        return $q->orderByDesc('accepted_at')->get()->map(fn ($r) => (array) $r)->toArray();
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function createEntry(ActorScope $actor, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'POST',
            '/api/v1/feed-entries',
            $input,
            function () use ($actor) {
                if ($actor->isOperator()) {
                    throw new AccessDeniedHttpException('Operator tidak memiliki izin mencatat mutasi gudang.');
                }
            },
            function () use ($actor, $input, $key) {
                $feedTypeId = (string) $input['feed_type_id'];
                $direction = (string) $input['direction'];
                $quantityKg = (string) $input['quantity_kg'];
                $kind = (string) $input['kind'];

                $signedKg = ($direction === 'out' ? '-' : '').$quantityKg;

                // Apply atomic balance update with check constraint
                FeedProjection::apply($feedTypeId, $signedKg, $kind, $key, 1);

                $id = (string) ($input['id'] ?? Str::uuid());
                $unitPrice = $input['unit_price_idr'] ?? null;
                $purchaseTotal = null;
                if ($unitPrice !== null) {
                    $total = ((float) $quantityKg) * ((float) $unitPrice);
                    $purchaseTotal = number_format($total, 2, '.', '');
                }

                $entryData = [
                    'id' => $id,
                    'farm_id' => $actor->farmId,
                    'feed_type_id' => $feedTypeId,
                    'business_date' => $input['business_date'],
                    'kind' => $kind,
                    'delta_kg' => $quantityKg,
                    'unit_price_idr' => $unitPrice,
                    'purchase_total_idr' => $purchaseTotal,
                    'supplier' => $input['supplier'] ?? null,
                    'reason' => $input['reason'] ?? null,
                    'accepted_at' => now(),
                ];

                DB::table('feed_entries')->insert($entryData);

                ChangeWriter::append(
                    $actor,
                    'feed_entry',
                    $id,
                    'upsert',
                    $entryData
                );

                return Ack::fromArray([
                    'status' => 'accepted',
                    'id' => $id,
                    'version' => 1,
                ]);
            }
        );
    }
}
