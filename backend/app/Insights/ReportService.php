<?php

declare(strict_types=1);

namespace App\Insights;

use App\Support\ActorScope;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;

class ReportService
{
    public const MAX_DAYS = 183;

    /**
     * @return array<string, mixed>
     */
    public function dashboard(ActorScope $actor, string $businessDate): array
    {
        $this->assertManager($actor);

        $timezone = $this->timezoneFor($actor->farmId);
        $cages = DB::table('cages')
            ->where('farm_id', $actor->farmId)
            ->where('active', true)
            ->orderBy('code')
            ->get();

        $rows = [];
        $expected = 0;
        $accepted = 0;
        $eggs = null;
        $feed = null;

        foreach ($cages as $cage) {
            $flock = $this->activeFlockForCage($actor->farmId, (string) $cage->id, $businessDate);

            if ($flock === null) {
                $rows[] = [
                    'cage_id' => (string) $cage->id,
                    'flock_id' => null,
                    'business_date' => $businessDate,
                    'record_state' => 'not_expected',
                    'eggs_count' => null,
                    'feed_kg' => null,
                ];

                continue;
            }

            $expected++;
            $record = $this->acceptedRecord($actor->farmId, (string) $flock->id, $businessDate);

            if ($record === null) {
                $rows[] = [
                    'cage_id' => (string) $cage->id,
                    'flock_id' => (string) $flock->id,
                    'business_date' => $businessDate,
                    'record_state' => 'missing',
                    'eggs_count' => null,
                    'feed_kg' => null,
                ];

                continue;
            }

            $accepted++;
            $eggs = ($eggs ?? 0) + (int) $record->eggs_count;
            $feed = $this->addKg($feed, (string) $record->feed_kg);

            $rows[] = [
                'cage_id' => (string) $cage->id,
                'flock_id' => (string) $flock->id,
                'business_date' => $businessDate,
                'record_state' => 'accepted',
                'eggs_count' => (int) $record->eggs_count,
                'feed_kg' => (string) $record->feed_kg,
            ];
        }

        $openIncidents = DB::table('incidents')
            ->where('farm_id', $actor->farmId)
            ->whereIn('status', ['open', 'in_progress'])
            ->count();

        $lowStock = DB::table('feed_types')
            ->join('feed_balances', 'feed_balances.feed_type_id', '=', 'feed_types.id')
            ->where('feed_types.farm_id', $actor->farmId)
            ->where('feed_types.active', true)
            ->whereColumn('feed_balances.quantity_kg', '<', 'feed_types.minimum_kg')
            ->pluck('feed_types.id')
            ->map(fn ($id) => (string) $id)
            ->toArray();

        return [
            'business_date' => $businessDate,
            'timezone' => $timezone,
            'as_of' => now()->toIso8601String(),
            'expected_records' => $expected,
            'accepted_records' => $accepted,
            'eggs_count' => $eggs,
            'feed_kg' => $feed,
            'open_incidents' => $openIncidents,
            'low_stock_feed_type_ids' => $lowStock,
            'cages' => $rows,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function operations(ActorScope $actor, string $from, string $to): array
    {
        $this->assertManager($actor);
        $this->assertPeriod($from, $to);

        $timezone = $this->timezoneFor($actor->farmId);

        $flocks = DB::table('flocks')
            ->where('farm_id', $actor->farmId)
            ->get();

        $rows = [];
        $expected = 0;
        $accepted = 0;
        $eggs = null;
        $feed = null;

        $cursor = new \DateTimeImmutable($from);
        $end = new \DateTimeImmutable($to);

        while ($cursor <= $end) {
            $date = $cursor->format('Y-m-d');

            foreach ($flocks as $flock) {
                if (! $this->flockExpectedOn($flock, $date)) {
                    continue;
                }

                $expected++;
                $record = $this->acceptedRecord($actor->farmId, (string) $flock->id, $date);

                if ($record === null) {
                    $rows[] = [
                        'business_date' => $date,
                        'cage_id' => (string) $flock->cage_id,
                        'flock_id' => (string) $flock->id,
                        'record_state' => 'missing',
                        'eggs_count' => null,
                        'feed_kg' => null,
                        'mortality_count' => null,
                        'condition' => null,
                    ];

                    continue;
                }

                $accepted++;
                $eggs = ($eggs ?? 0) + (int) $record->eggs_count;
                $feed = $this->addKg($feed, (string) $record->feed_kg);

                $rows[] = [
                    'business_date' => $date,
                    'cage_id' => (string) $flock->cage_id,
                    'flock_id' => (string) $flock->id,
                    'record_state' => 'accepted',
                    'eggs_count' => (int) $record->eggs_count,
                    'feed_kg' => (string) $record->feed_kg,
                    'mortality_count' => (int) $record->mortality_count,
                    'condition' => (string) $record->condition,
                ];
            }

            $cursor = $cursor->modify('+1 day');
        }

        return [
            'from' => $from,
            'to' => $to,
            'timezone' => $timezone,
            'as_of' => now()->toIso8601String(),
            'expected_records' => $expected,
            'accepted_records' => $accepted,
            'eggs_count' => $eggs,
            'feed_kg' => $feed,
            'rows' => $rows,
        ];
    }

    private function assertManager(ActorScope $actor): void
    {
        if ($actor->isOperator()) {
            throw new AccessDeniedHttpException(
                'Laporan hanya untuk pengelola.'
            );
        }
    }

    private function assertPeriod(string $from, string $to): void
    {
        $fromDate = \DateTimeImmutable::createFromFormat('Y-m-d', $from);
        $toDate = \DateTimeImmutable::createFromFormat('Y-m-d', $to);

        if ($fromDate === false || $toDate === false) {
            throw ValidationException::withMessages(['from' => ['Format tanggal tidak valid.']]);
        }

        if ($toDate < $fromDate) {
            throw ValidationException::withMessages(['to' => ['Tanggal akhir sebelum awal.']]);
        }

        $days = (int) $fromDate->diff($toDate)->days + 1;
        if ($days > self::MAX_DAYS) {
            throw ValidationException::withMessages(['from' => ['Rentang maksimal 183 hari.']]);
        }
    }

    private function timezoneFor(string $farmId): string
    {
        $tz = DB::table('farms')->where('id', $farmId)->value('timezone');

        return $tz ? (string) $tz : 'UTC';
    }

    private function activeFlockForCage(string $farmId, string $cageId, string $businessDate): ?object
    {
        $flock = DB::table('flocks')
            ->where('farm_id', $farmId)
            ->where('cage_id', $cageId)
            ->where('placed_on', '<=', $businessDate)
            ->where(function ($q) use ($businessDate) {
                $q->whereNull('finished_on')->orWhere('finished_on', '>=', $businessDate);
            })
            ->orderByDesc('placed_on')
            ->first();

        return $flock ?: null;
    }

    private function flockExpectedOn(object $flock, string $date): bool
    {
        if ((string) $flock->placed_on > $date) {
            return false;
        }

        if ($flock->finished_on !== null && (string) $flock->finished_on < $date) {
            return false;
        }

        return true;
    }

    private function acceptedRecord(string $farmId, string $flockId, string $businessDate): ?object
    {
        return DB::table('daily_records')
            ->where('farm_id', $farmId)
            ->where('flock_id', $flockId)
            ->where('business_date', $businessDate)
            ->first() ?: null;
    }

    private function addKg(?string $acc, string $kg): string
    {
        $sum = (float) ($acc ?? '0') + (float) $kg;

        return number_format($sum, 2, '.', '');
    }
}
