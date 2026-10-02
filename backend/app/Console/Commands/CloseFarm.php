<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Close a farm: export an owner-facing snapshot, revoke access and journal the
 * act (AC-46). The farm row and its ledger are preserved — closure never hard
 * deletes business records; deletions, if any, flow through retention and the
 * append-only `retention.deletion` journal so a restore can reapply them after
 * the backup timestamp.
 */
final class CloseFarm extends Command
{
    protected $signature = 'ternava:close-farm {farm : Farm UUID to close}';

    protected $description = 'Tutup farm dengan export, pencabutan akses dan jurnal (AC-46).';

    public function handle(): int
    {
        $farmId = (string) $this->argument('farm');

        $farm = DB::table('farms')->where('id', $farmId)->first();

        if (! $farm) {
            $this->error("Farm {$farmId} tidak ditemukan.");

            return self::FAILURE;
        }

        $snapshot = [
            'farm' => (array) $farm,
            'closed_at' => now()->toIso8601String(),
            'counts' => [
                'cages' => DB::table('cages')->where('farm_id', $farmId)->count(),
                'flocks' => DB::table('flocks')->where('farm_id', $farmId)->count(),
                'daily_records' => DB::table('daily_records')->where('farm_id', $farmId)->count(),
                'feed_entries' => DB::table('feed_entries')->where('farm_id', $farmId)->count(),
                'incidents' => DB::table('incidents')->where('farm_id', $farmId)->count(),
            ],
        ];

        $path = 'exports/farm-'.$farmId.'-'.now()->format('YmdHis').'.json';
        Storage::disk('private')->put($path, json_encode($snapshot, JSON_PRETTY_PRINT));

        DB::transaction(function () use ($farmId, $path): void {
            // Revoke access by deactivating memberships (users are not deleted;
            // the ledger keeps referencing actor IDs, per operations-security.md).
            DB::table('memberships')
                ->where('farm_id', $farmId)
                ->update(['active' => false]);

            DB::table('audit_events')->insert([
                'id' => (string) Str::uuid(),
                'farm_id' => $farmId,
                'actor_id' => null,
                'action' => 'farm.closure',
                'resource_type' => 'farms',
                'resource_id' => $farmId,
                'metadata' => json_encode(['export' => $path]),
                'accepted_at' => now(),
            ]);
        });

        $this->info("Farm {$farmId} ditutup. Export: {$path}");

        return self::SUCCESS;
    }
}
