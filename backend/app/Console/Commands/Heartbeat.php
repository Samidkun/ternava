<?php

declare(strict_types=1);

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Throwable;

/**
 * Worker/scheduler heartbeat + degraded-service metrics (T43, AC-45).
 *
 * AC-45 requires that a service incident is *distinguishable* — API failure,
 * queue failure, backup failure and push failure must be separately visible,
 * not collapsed into one "down" signal. This command is the single writer of
 * that machine-readable status: a small JSON document per role that an external
 * probe can read, plus aggregate counters (queue oldest age, failed jobs,
 * undelivered push events) that the health monitor turns into thresholds.
 *
 * Design notes:
 *  - The heartbeat file is written to the PRIVATE disk; the endpoint that
 *    exposes status (T43 health-monitor) reads it, and nothing in the file is a
 *    secret.
 *  - `--role` is required so worker and scheduler are monitored independently:
 *    a stuck worker must not hide behind a healthy scheduler.
 *  - FCM/push degradation is a SEPARATE field (`push_degraded`) — it must not
 *    make the API look unhealthy (docs/operations-security.md: "FCM down →
 *    status notification degraded, tidak mematikan API record").
 */
final class Heartbeat extends Command
{
    protected $signature = 'ternava:heartbeat
        {--role=worker : worker atau scheduler}
        {--json : cetak dokumen status ke stdout sebagai JSON}';

    protected $description = 'Tulis heartbeat worker/scheduler dan metrik gangguan (AC-45).';

    public function handle(): int
    {
        $role = (string) $this->option('role');

        if (! in_array($role, ['worker', 'scheduler'], true)) {
            $this->error('role harus "worker" atau "scheduler".');

            return self::FAILURE;
        }

        $status = [
            'role' => $role,
            'pid' => getmypid() ?: 0,
            'host' => gethostname() ?: 'unknown',
            'at' => now()->toISOString(),
            'app_env' => (string) config('app.env'),
            'queue_connection' => (string) config('queue.default'),
            'metrics' => $this->metrics(),
        ];

        Storage::disk('local')->put(
            'heartbeats/'.$role.'.json',
            json_encode($status, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
        );

        if ((bool) $this->option('json')) {
            $this->line(json_encode($status, JSON_UNESCAPED_SLASHES));
        } else {
            $this->info('heartbeat '.$role.' ditulis pada '.$status['at']);
        }

        return self::SUCCESS;
    }

    /**
     * Aggregate metrics that distinguish failure modes. Every query is guarded
     * so a missing table (e.g. a fresh install) yields a null instead of a 500.
     *
     * @return array<string, int|null>
     */
    private function metrics(): array
    {
        return [
            'queue_oldest_seconds' => $this->scalar(
                'SELECT coalesce(extract(epoch from (now() - to_timestamp(min(created_at)))), 0)::bigint FROM jobs'
            ),
            'queue_depth' => $this->scalar('SELECT count(*) FROM jobs'),
            'failed_jobs' => $this->scalar('SELECT count(*) FROM failed_jobs'),
            'push_undelivered' => $this->scalar(
                'SELECT count(*) FROM notification_outbox WHERE processed_at IS NULL'
            ),
            'push_degraded_devices' => $this->scalar(
                'SELECT count(*) FROM push_devices WHERE enabled = false'
            ),
        ];
    }

    private function scalar(string $sql): ?int
    {
        try {
            $value = DB::selectOne($sql);

            return $value === null ? null : (int) array_values((array) $value)[0];
        } catch (Throwable) {
            return null;
        }
    }
}
