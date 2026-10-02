<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Enforce the bounded retention windows from docs/operations-security.md.
 *
 * Invariants (AC-46):
 *  - Business records, ledger entries, revisions and the audit trail live for
 *    the 730d window and are purged as a complete group, never partially.
 *  - Deduplication receipts are NEVER purged while the farm is active, so an
 *    old queued intent can still be replayed without re-applying its business
 *    effect (App\Support\MutationExecutor).
 *  - Every purge is recorded in the append-only audit trail with the action
 *    `retention.deletion` so a restore can reapply deletions after its backup
 *    timestamp.
 */
final class ApplyRetention extends Command
{
    protected $signature = 'ternava:retention';

    protected $description = 'Terapkan jendela retensi operasional (AC-46).';

    public function handle(): int
    {
        $business = (int) config('ternava.retention.business_days', 730);
        $photo = (int) config('ternava.retention.photo_days', 180);
        $inbox = (int) config('ternava.retention.inbox_days', 90);
        $delta = (int) config('ternava.retention.delta_days', 30);

        $this->purgeRows('daily_revisions', 'accepted_at', $business, 'daily_records', 'daily_record_id');
        $this->purgeRows('feed_entries', 'accepted_at', $business);
        $this->purgeRows('population_entries', 'accepted_at', $business);
        $this->purgeRows('daily_records', 'accepted_at', $business);
        $this->purgeRows('audit_events', 'accepted_at', $business);
        $this->purgeRows('sync_changes', 'accepted_at', $delta);
        $this->purgeRows('inbox_items', 'updated_at', $inbox);

        $this->purgeAttachments($photo);

        $this->info('Retensi selesai. Receipt dedup dipertahankan selama farm aktif.');

        return self::SUCCESS;
    }

    /**
     * @param  string|null  $parentTable  table providing farm_id when $table lacks it
     * @param  string|null  $parentKey  column on $table pointing at $parentTable.id
     */
    private function purgeRows(
        string $table,
        string $column,
        int $days,
        ?string $parentTable = null,
        ?string $parentKey = null
    ): void {
        $cutoff = now()->subDays($days);

        $expired = DB::table($table)->where($column, '<', $cutoff);
        $count = (clone $expired)->count();

        if ($count === 0) {
            return;
        }

        if ($parentTable !== null && $parentKey !== null) {
            $farmIds = DB::table($table)
                ->join($parentTable, $table.'.'.$parentKey, '=', $parentTable.'.id')
                ->where($table.'.'.$column, '<', $cutoff)
                ->distinct()
                ->pluck($parentTable.'.farm_id')
                ->all();
        } else {
            $farmIds = (clone $expired)->distinct()->pluck('farm_id')->all();
        }

        DB::transaction(function () use ($table, $column, $cutoff, $farmIds, $count, $days): void {
            DB::table($table)->where($column, '<', $cutoff)->delete();

            foreach ($farmIds as $farmId) {
                DB::table('audit_events')->insert([
                    'id' => (string) Str::uuid(),
                    'farm_id' => (string) $farmId,
                    'actor_id' => null,
                    'action' => 'retention.deletion',
                    'resource_type' => $table,
                    'resource_id' => (string) Str::uuid(),
                    'metadata' => json_encode([
                        'table' => $table,
                        'window_days' => $days,
                        'rows' => $count,
                    ]),
                    'accepted_at' => now(),
                ]);
            }
        });
    }

    private function purgeAttachments(int $days): void
    {
        $cutoff = now()->subDays($days);

        $expired = DB::table('attachments')->where('accepted_at', '<', $cutoff)->get();

        if ($expired->isEmpty()) {
            return;
        }

        DB::transaction(function () use ($expired, $days): void {
            foreach ($expired as $attachment) {
                Storage::disk('private')->delete((string) $attachment->storage_key);

                DB::table('attachments')->where('id', $attachment->id)->delete();

                DB::table('audit_events')->insert([
                    'id' => (string) Str::uuid(),
                    'farm_id' => (string) $attachment->farm_id,
                    'actor_id' => null,
                    'action' => 'retention.deletion',
                    'resource_type' => 'attachments',
                    'resource_id' => (string) $attachment->id,
                    'metadata' => json_encode([
                        'table' => 'attachments',
                        'window_days' => $days,
                        'rows' => 1,
                    ]),
                    'accepted_at' => now(),
                ]);
            }
        });
    }
}
