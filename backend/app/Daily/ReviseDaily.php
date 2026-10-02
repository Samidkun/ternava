<?php

declare(strict_types=1);

namespace App\Daily;

use App\Contracts\Dto\Ack;
use App\Feed\FeedProjection;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use App\Support\MutationExecutor;
use App\Support\WireValidator;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class ReviseDaily
{
    /**
     * @param  array<string, mixed>  $input
     */
    public function handle(ActorScope $actor, string $dailyId, array $input, string $key): Ack
    {
        try {
            return MutationExecutor::run(
                $actor,
                $key,
                'POST',
                "/api/v1/daily-records/{$dailyId}/revisions",
                $input,
                function () use ($actor) {
                    if ($actor->isOperator()) {
                        throw new AccessDeniedHttpException('Operator tidak memiliki izin merevisi catatan harian.');
                    }
                },
                function () use ($actor, $dailyId, $input) {
                    $record = DB::table('daily_records')
                        ->where('id', $dailyId)
                        ->where('farm_id', $actor->farmId)
                        ->first();

                    if (! $record) {
                        throw new NotFoundHttpException('Catatan harian tidak ditemukan.');
                    }

                    // 1. Version conflict check
                    $baseVersion = (int) ($input['base_version'] ?? 0);
                    if ((int) $record->version !== $baseVersion) {
                        throw new ConflictHttpException((string) $record->version);
                    }

                    // 2. Immutability check: flock_id and business_date cannot be moved
                    if (isset($input['flock_id']) && (string) $input['flock_id'] !== (string) $record->flock_id) {
                        throw new UnprocessableEntityHttpException('Kelompok ayam tidak dapat dipindahkan dalam revisi.');
                    }
                    if (isset($input['business_date']) && (string) $input['business_date'] !== (string) $record->business_date) {
                        throw new UnprocessableEntityHttpException('Tanggal catatan tidak dapat diubah dalam revisi.');
                    }

                    $newVersion = (int) $record->version + 1;
                    $newFeedKg = WireValidator::requireKg($input['feed_kg']);
                    $newFeedTypeId = (string) $input['feed_type_id'];
                    $oldFeedKg = (string) $record->feed_kg;
                    $oldFeedTypeId = (string) $record->feed_type_id;

                    // 3. Feed stock compensation: reverse old feed, apply new feed
                    if ($oldFeedKg !== '0.00') {
                        // Reversal adds feed back
                        FeedProjection::apply($oldFeedTypeId, $oldFeedKg, 'daily_reversal', $dailyId, $newVersion);
                    }
                    if ($newFeedKg !== '0.00') {
                        // Deduct new feed
                        FeedProjection::apply($newFeedTypeId, '-'.$newFeedKg, 'daily_usage', $dailyId, $newVersion);
                    }

                    // 4. Archive old record snapshot into daily_revisions
                    $snapshot = [
                        'id' => $record->id,
                        'farm_id' => $record->farm_id,
                        'flock_id' => $record->flock_id,
                        'business_date' => $record->business_date,
                        'feed_type_id' => $record->feed_type_id,
                        'feed_kg' => $record->feed_kg,
                        'eggs_count' => $record->eggs_count,
                        'mortality_count' => $record->mortality_count,
                        'condition' => $record->condition,
                        'notes' => $record->notes,
                        'version' => $record->version,
                        'recorded_by' => $record->recorded_by,
                        'accepted_at' => $record->accepted_at,
                        'updated_at' => $record->updated_at,
                    ];

                    DB::table('daily_revisions')->insert([
                        'id' => (string) Str::uuid(),
                        'daily_record_id' => $dailyId,
                        'version' => $record->version,
                        'snapshot' => json_encode($snapshot),
                        'reason' => $input['reason'],
                        'actor_id' => $actor->actorId,
                        'accepted_at' => now(),
                    ]);

                    // 5. Update daily_records with new revision
                    $updateData = [
                        'feed_type_id' => $newFeedTypeId,
                        'feed_kg' => $newFeedKg,
                        'eggs_count' => (int) $input['eggs_count'],
                        'mortality_count' => isset($input['mortality_count']) ? (int) $input['mortality_count'] : null,
                        'condition' => (string) ($input['condition'] ?? $record->condition),
                        'notes' => $input['notes'] ?? $record->notes,
                        'version' => $newVersion,
                        'updated_at' => now(),
                    ];

                    DB::table('daily_records')->where('id', $dailyId)->update($updateData);

                    // 6. Record in sync_changes
                    ChangeWriter::append(
                        $actor,
                        'daily_record',
                        $dailyId,
                        'upsert',
                        array_merge(['id' => $dailyId], $updateData)
                    );

                    return Ack::fromArray([
                        'status' => 'accepted',
                        'id' => $dailyId,
                        'version' => $newVersion,
                    ]);
                }
            );
        } catch (UniqueConstraintViolationException $e) {
            // Two admins revised the same base_version concurrently. The
            // in-transaction version check cannot close that window, so the
            // unique index (daily_record_id, version) is the real guard: the
            // loser lands here. Surface the documented 409 and leave the
            // record, snapshot and ledger untouched. (AC-29.)
            if (str_contains($e->getMessage(), 'daily_revisions_daily_record_id_version_unique')) {
                $current = DB::table('daily_records')->where('id', $dailyId)->value('version');

                throw new ConflictHttpException((string) $current);
            }

            throw $e;
        }
    }
}
