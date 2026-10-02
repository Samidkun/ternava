<?php

declare(strict_types=1);

namespace App\Sync;

use App\Support\ActorScope;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class SyncService
{
    /**
     * @return array<string, mixed>
     */
    public function bootstrap(ActorScope $actor, ?string $cursor = null, int $limit = 50): array
    {
        $membership = DB::table('memberships')
            ->where('farm_id', $actor->farmId)
            ->where('user_id', $actor->actorId)
            ->first();

        $scopeVersion = $membership ? (int) $membership->scope_version : 1;

        if ($cursor) {
            $claims = CursorCodec::decode($cursor);
            if (
                $claims['farm_id'] !== $actor->farmId ||
                $claims['actor_id'] !== $actor->actorId ||
                (int) $claims['scope_version'] !== $scopeVersion
            ) {
                throw new ConflictHttpException('CURSOR_RESET_REQUIRED: Scope version atau hak akses berubah.');
            }

            $highWatermark = (int) $claims['high_watermark'];
            $lastSequence = (int) ($claims['last_sequence'] ?? 0);
        } else {
            $counter = DB::table('sync_counters')
                ->where('farm_id', $actor->farmId)
                ->value('last_sequence');

            $highWatermark = $counter !== null ? (int) $counter : 0;
            $lastSequence = 0;
        }

        $changesQuery = DB::table('sync_changes')
            ->where('farm_id', $actor->farmId)
            ->where('sequence', '>', $lastSequence)
            ->where('sequence', '<=', $highWatermark)
            ->orderBy('sequence')
            ->limit($limit + 1)
            ->get();

        $hasMore = $changesQuery->count() > $limit;
        $sliced = $changesQuery->take($limit);

        $changes = [];
        $lastProcessedSeq = $lastSequence;

        foreach ($sliced as $row) {
            $lastProcessedSeq = (int) $row->sequence;
            $changes[] = [
                'resource_type' => $row->resource_type,
                'resource_id' => $row->resource_id,
                'action' => $row->action,
                'value' => $row->snapshot ? json_decode((string) $row->snapshot, true) : null,
            ];
        }

        $nextCursor = null;
        if ($hasMore) {
            $nextCursor = CursorCodec::encode([
                'farm_id' => $actor->farmId,
                'actor_id' => $actor->actorId,
                'scope_version' => $scopeVersion,
                'high_watermark' => $highWatermark,
                'last_sequence' => $lastProcessedSeq,
                'expires_at' => now()->addMinutes(15)->timestamp,
            ]);
        } elseif ($highWatermark > 0) {
            $nextCursor = CursorCodec::encode([
                'farm_id' => $actor->farmId,
                'actor_id' => $actor->actorId,
                'scope_version' => $scopeVersion,
                'high_watermark' => $highWatermark,
                'last_sequence' => $highWatermark,
                'expires_at' => now()->addMinutes(15)->timestamp,
            ]);
        }

        return [
            'scope_version' => $scopeVersion,
            'as_of' => now()->toISOString(),
            'changes' => $changes,
            'next_cursor' => $nextCursor,
            'has_more' => $hasMore,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function changes(ActorScope $actor, ?string $cursor = null, int $limit = 50): array
    {
        $membership = DB::table('memberships')
            ->where('farm_id', $actor->farmId)
            ->where('user_id', $actor->actorId)
            ->first();

        $scopeVersion = $membership ? (int) $membership->scope_version : 1;

        if (! $cursor) {
            return $this->bootstrap($actor, null, $limit);
        }

        $claims = CursorCodec::decode($cursor);
        if (
            $claims['farm_id'] !== $actor->farmId ||
            $claims['actor_id'] !== $actor->actorId ||
            (int) $claims['scope_version'] !== $scopeVersion
        ) {
            throw new ConflictHttpException('CURSOR_RESET_REQUIRED: Scope version berubah.');
        }

        $fromSequence = (int) ($claims['last_sequence'] ?? $claims['high_watermark']);

        $counter = DB::table('sync_counters')
            ->where('farm_id', $actor->farmId)
            ->value('last_sequence');
        $currentHighWatermark = $counter !== null ? (int) $counter : 0;

        $changesQuery = DB::table('sync_changes')
            ->where('farm_id', $actor->farmId)
            ->where('sequence', '>', $fromSequence)
            ->where('sequence', '<=', $currentHighWatermark)
            ->orderBy('sequence')
            ->limit($limit + 1)
            ->get();

        $hasMore = $changesQuery->count() > $limit;
        $sliced = $changesQuery->take($limit);

        $changes = [];
        $lastProcessedSeq = $fromSequence;

        foreach ($sliced as $row) {
            $lastProcessedSeq = (int) $row->sequence;
            $changes[] = [
                'resource_type' => $row->resource_type,
                'resource_id' => $row->resource_id,
                'action' => $row->action,
                'value' => $row->snapshot ? json_decode((string) $row->snapshot, true) : null,
            ];
        }

        $nextCursor = CursorCodec::encode([
            'farm_id' => $actor->farmId,
            'actor_id' => $actor->actorId,
            'scope_version' => $scopeVersion,
            'high_watermark' => $currentHighWatermark,
            'last_sequence' => $lastProcessedSeq,
            'expires_at' => now()->addMinutes(15)->timestamp,
        ]);

        return [
            'scope_version' => $scopeVersion,
            'as_of' => now()->toISOString(),
            'changes' => $changes,
            'next_cursor' => $nextCursor,
            'has_more' => $hasMore,
        ];
    }
}
