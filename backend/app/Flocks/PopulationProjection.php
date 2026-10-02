<?php

declare(strict_types=1);

namespace App\Flocks;

use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PopulationProjection
{
    /**
     * Verify that running population never drops below zero.
     *
     * @param  array<string, mixed>  $replacement
     *
     * @throws ValidationException
     */
    public static function assertPrefixes(string $flockId, array $replacement = []): void
    {
        $flock = DB::table('flocks')->where('id', $flockId)->first();
        if (! $flock) {
            return;
        }

        $initial = (int) ($replacement['initial_population'] ?? $flock->initial_population);

        $entries = DB::table('population_entries')
            ->where('flock_id', $flockId)
            ->orderBy('business_date')
            ->orderBy('accepted_at')
            ->get();

        $running = $initial;
        foreach ($entries as $entry) {
            $running += (int) $entry->delta_count;
            if ($running < 0) {
                throw ValidationException::withMessages([
                    'population_change' => ['Populasi pada suatu tanggal akan menjadi negatif.'],
                ]);
            }
        }
    }

    public static function hasDailyRecords(string $flockId): bool
    {
        return DB::table('daily_records')->where('flock_id', $flockId)->exists();
    }
}
