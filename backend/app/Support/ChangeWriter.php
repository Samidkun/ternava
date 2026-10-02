<?php

declare(strict_types=1);

namespace App\Support;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class ChangeWriter
{
    /**
     * Append a change to sync_changes using a monotonic locked counter per farm.
     *
     * @param  array<string, mixed>|null  $snapshot
     */
    public static function append(
        ActorScope $actor,
        string $resourceType,
        string $resourceId,
        string $action, // 'upsert' or 'remove'
        ?array $snapshot = null
    ): int {
        // Lock or initialize counter for farm
        $counter = DB::table('sync_counters')
            ->where('farm_id', $actor->farmId)
            ->lockForUpdate()
            ->first();

        if (! $counter) {
            DB::table('sync_counters')->insert([
                'id' => (string) Str::uuid(),
                'farm_id' => $actor->farmId,
                'last_sequence' => 1,
            ]);
            $seq = 1;
        } else {
            $seq = (int) $counter->last_sequence + 1;
            DB::table('sync_counters')
                ->where('farm_id', $actor->farmId)
                ->update(['last_sequence' => $seq]);
        }

        DB::table('sync_changes')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $actor->farmId,
            'sequence' => $seq,
            'resource_type' => $resourceType,
            'resource_id' => $resourceId,
            'action' => $action,
            'snapshot' => $snapshot ? json_encode($snapshot) : null,
            'accepted_at' => now(),
        ]);

        return $seq;
    }
}
