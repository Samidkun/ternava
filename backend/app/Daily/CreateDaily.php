<?php

declare(strict_types=1);

namespace App\Daily;

use App\Contracts\Dto\Ack;
use App\Feed\FeedProjection;
use App\Flocks\PopulationProjection;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use App\Support\MutationExecutor;
use App\Support\WireValidator;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class CreateDaily
{
    /**
     * @param  array<string, mixed>  $input
     */
    public function handle(ActorScope $actor, array $input, string $key): Ack
    {
        $flockId = (string) $input['flock_id'];
        $businessDate = (string) $input['business_date'];

        // 1. Authorize flock access
        DailyPolicy::authorizeFlockAccess($actor, $flockId);

        // 2. Validate feed_kg format
        $feedKg = WireValidator::requireKg($input['feed_kg']);

        try {
            return MutationExecutor::run(
                $actor,
                $key,
                'POST',
                '/api/v1/daily-records',
                $input,
                function () use ($actor, $flockId) {
                    DailyPolicy::authorizeFlockAccess($actor, $flockId);
                },
                function () use ($actor, $flockId, $businessDate, $input, $feedKg) {
                    // Check if daily record already exists for (farm_id, flock_id, business_date)
                    $exists = DB::table('daily_records')
                        ->where('farm_id', $actor->farmId)
                        ->where('flock_id', $flockId)
                        ->where('business_date', $businessDate)
                        ->exists();

                    if ($exists) {
                        throw new ConflictHttpException('DAILY_ALREADY_EXISTS: Catatan harian untuk kelompok dan tanggal ini sudah ada.');
                    }

                    $recordId = (string) ($input['id'] ?? Str::uuid());
                    $feedTypeId = (string) $input['feed_type_id'];
                    $eggsCount = (int) $input['eggs_count'];
                    $mortalityCount = isset($input['mortality_count']) ? (int) $input['mortality_count'] : null;
                    $condition = (string) ($input['condition'] ?? 'normal');
                    $notes = $input['notes'] ?? null;

                    // 3. Insert daily record first (so FK references from feed_entries/population_entries succeed)
                    $recordData = [
                        'id' => $recordId,
                        'farm_id' => $actor->farmId,
                        'flock_id' => $flockId,
                        'business_date' => $businessDate,
                        'feed_type_id' => $feedTypeId,
                        'feed_kg' => $feedKg,
                        'eggs_count' => $eggsCount,
                        'mortality_count' => $mortalityCount,
                        'condition' => $condition,
                        'notes' => $notes,
                        'version' => 1,
                        'recorded_by' => $actor->actorId,
                        'accepted_at' => now(),
                        'updated_at' => now(),
                    ];
                    DB::table('daily_records')->insert($recordData);

                    // 4. Atomically deduct feed balance if feed_kg > 0
                    if ($feedKg !== '0.00') {
                        FeedProjection::apply($feedTypeId, '-'.$feedKg, 'daily_usage', $recordId, 1);

                        DB::table('feed_entries')->insert([
                            'id' => (string) Str::uuid(),
                            'farm_id' => $actor->farmId,
                            'feed_type_id' => $feedTypeId,
                            'business_date' => $businessDate,
                            'kind' => 'daily_usage',
                            'delta_kg' => $feedKg,
                            'daily_record_id' => $recordId,
                            'daily_version' => 1,
                            'accepted_at' => now(),
                        ]);
                    }

                    // 5. Record mortality in population_entries if mortality_count > 0
                    if ($mortalityCount !== null && $mortalityCount > 0) {
                        DB::table('population_entries')->insert([
                            'id' => (string) Str::uuid(),
                            'farm_id' => $actor->farmId,
                            'flock_id' => $flockId,
                            'business_date' => $businessDate,
                            'delta_count' => -$mortalityCount,
                            'daily_record_id' => $recordId,
                            'daily_version' => 1,
                            'reason' => 'Kematian harian',
                            'accepted_at' => now(),
                        ]);

                        // Assert running population doesn't go below 0
                        PopulationProjection::assertPrefixes($flockId);
                    }

                    // 6. Record in sync_changes
                    ChangeWriter::append(
                        $actor,
                        'daily_record',
                        $recordId,
                        'upsert',
                        $recordData
                    );

                    return Ack::fromArray([
                        'status' => 'accepted',
                        'id' => $recordId,
                        'version' => 1,
                    ]);
                }
            );
        } catch (UniqueConstraintViolationException $e) {
            // Two operators raced to create the same (farm, flock, date). The
            // pre-check above cannot close that window; the unique index does.
            // Surface the documented 409 instead of a raw 500. (AC-28.)
            if (str_contains($e->getMessage(), 'daily_records_farm_id_flock_id_business_date_unique')) {
                throw new ConflictHttpException('DAILY_ALREADY_EXISTS: Catatan harian untuk kelompok dan tanggal ini sudah ada.');
            }

            throw $e;
        }
    }
}
