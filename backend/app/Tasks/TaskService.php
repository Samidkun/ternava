<?php

declare(strict_types=1);

namespace App\Tasks;

use App\Contracts\Dto\Ack;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use App\Support\MutationExecutor;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class TaskService
{
    public const MAX_CHECKLIST_ITEMS = 20;

    /**
     * Derive literal checklist items from the SOP text. One line = one item.
     * IDs are derived deterministically so they stay stable across syncs.
     *
     * @return array<int, array{id: string, label: string}>
     */
    public static function checklistFromSop(string $sop): array
    {
        $lines = preg_split('/\r\n|\r|\n/', $sop) ?: [];
        $items = [];

        foreach ($lines as $line) {
            $label = trim($line);
            if ($label === '') {
                continue;
            }

            $items[] = [
                'id' => (string) Str::uuid(),
                'label' => $label,
            ];

            if (count($items) >= self::MAX_CHECKLIST_ITEMS) {
                break;
            }
        }

        return $items;
    }

    /**
     * @param  array<string, mixed>  $query
     * @return array<int, array<string, mixed>>
     */
    public function listTemplates(ActorScope $actor, array $query = []): array
    {
        return DB::table('task_templates')
            ->where('farm_id', $actor->farmId)
            ->orderBy('updated_at', 'desc')
            ->get()
            ->map(fn ($r) => (array) $r)
            ->toArray();
    }

    /**
     * @return array<string, mixed>
     */
    public function getTemplate(ActorScope $actor, string $id): array
    {
        $row = DB::table('task_templates')
            ->where('id', $id)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $row) {
            throw new NotFoundHttpException('Template tugas tidak ditemukan.');
        }

        return (array) $row;
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function createTemplate(ActorScope $actor, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'POST',
            '/api/v1/task-templates',
            $input,
            function () use ($actor) {
                if ($actor->isOperator()) {
                    throw new AccessDeniedHttpException('Operator tidak memiliki izin membuat template tugas.');
                }
            },
            function () use ($actor, $input) {
                $cageId = (string) $input['cage_id'];
                $assigneeId = (string) $input['assignee_id'];

                $this->assertCageInFarm($actor, $cageId);
                $this->assertAssigneeAuthorized($actor, $assigneeId);

                $id = (string) ($input['id'] ?? Str::uuid());
                $data = [
                    'id' => $id,
                    'farm_id' => $actor->farmId,
                    'cage_id' => $cageId,
                    'assignee_id' => $assigneeId,
                    'title' => trim((string) $input['title']),
                    'kind' => (string) $input['kind'],
                    'sop' => (string) $input['sop'],
                    'start_on' => (string) $input['start_on'],
                    'end_on' => $input['end_on'] ?? null,
                    'local_time' => (string) $input['local_time'],
                    'recurrence' => (string) $input['recurrence'],
                    'active' => true,
                    'version' => 1,
                    'updated_at' => now(),
                ];

                DB::table('task_templates')->insert($data);

                ChangeWriter::append($actor, 'task_template', $id, 'upsert', $data);

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
    public function updateTemplate(ActorScope $actor, string $id, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'PATCH',
            "/api/v1/task-templates/{$id}",
            $input,
            function () use ($actor) {
                if ($actor->isOperator()) {
                    throw new AccessDeniedHttpException('Operator tidak memiliki izin mengubah template tugas.');
                }
            },
            function () use ($actor, $id, $input) {
                $template = DB::table('task_templates')
                    ->where('id', $id)
                    ->where('farm_id', $actor->farmId)
                    ->first();

                if (! $template) {
                    throw new NotFoundHttpException('Template tugas tidak ditemukan.');
                }

                $baseVersion = (int) ($input['base_version'] ?? 0);
                if ((int) $template->version !== $baseVersion) {
                    throw new ConflictHttpException((string) $template->version);
                }

                $cageId = (string) ($input['cage_id'] ?? $template->cage_id);
                $assigneeId = (string) ($input['assignee_id'] ?? $template->assignee_id);

                $this->assertCageInFarm($actor, $cageId);
                $this->assertAssigneeAuthorized($actor, $assigneeId);

                $newVersion = (int) $template->version + 1;
                $data = [
                    'cage_id' => $cageId,
                    'assignee_id' => $assigneeId,
                    'title' => trim((string) ($input['title'] ?? $template->title)),
                    'kind' => (string) ($input['kind'] ?? $template->kind),
                    'sop' => (string) ($input['sop'] ?? $template->sop),
                    'start_on' => (string) ($input['start_on'] ?? $template->start_on),
                    'end_on' => array_key_exists('end_on', $input) ? $input['end_on'] : $template->end_on,
                    'local_time' => (string) ($input['local_time'] ?? $template->local_time),
                    'recurrence' => (string) ($input['recurrence'] ?? $template->recurrence),
                    'active' => array_key_exists('active', $input) ? (bool) $input['active'] : (bool) $template->active,
                    'version' => $newVersion,
                    'updated_at' => now(),
                ];

                DB::table('task_templates')->where('id', $id)->update($data);

                ChangeWriter::append($actor, 'task_template', $id, 'upsert', array_merge(['id' => $id], $data));

                return Ack::fromArray([
                    'status' => 'accepted',
                    'id' => $id,
                    'version' => $newVersion,
                ]);
            }
        );
    }

    /**
     * @param  array<string, mixed>  $query
     * @return array<int, array<string, mixed>>
     */
    public function listRuns(ActorScope $actor, array $query = []): array
    {
        $q = DB::table('task_runs')->where('farm_id', $actor->farmId);

        if ($actor->isOperator()) {
            $q->where('assignee_id', $actor->actorId);
        }

        if (isset($query['from'])) {
            $q->where('business_date', '>=', $query['from']);
        }

        if (isset($query['to'])) {
            $q->where('business_date', '<=', $query['to']);
        }

        return $q->orderByDesc('business_date')
            ->get()
            ->map(fn ($r) => $this->presentRun((array) $r))
            ->toArray();
    }

    /**
     * @return array<string, mixed>
     */
    public function getRun(ActorScope $actor, string $id): array
    {
        $row = DB::table('task_runs')
            ->where('id', $id)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $row) {
            throw new NotFoundHttpException('Tugas tidak ditemukan.');
        }

        if ($actor->isOperator() && (string) $row->assignee_id !== $actor->actorId) {
            throw new NotFoundHttpException('Tugas tidak ditemukan.');
        }

        return $this->presentRun((array) $row);
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function createResult(ActorScope $actor, string $runId, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'POST',
            "/api/v1/task-runs/{$runId}/results",
            $input,
            function () use ($actor, $runId) {
                $run = DB::table('task_runs')->where('id', $runId)->first();
                if (! $run) {
                    throw new NotFoundHttpException('Tugas tidak ditemukan.');
                }
                if ($actor->isOperator() && (string) $run->assignee_id !== $actor->actorId) {
                    throw new AccessDeniedHttpException('Tugas ini bukan untuk Anda.');
                }
            },
            function () use ($actor, $runId, $input) {
                $run = DB::table('task_runs')
                    ->where('id', $runId)
                    ->where('farm_id', $actor->farmId)
                    ->first();

                if (! $run) {
                    throw new NotFoundHttpException('Tugas tidak ditemukan.');
                }

                if ((string) $run->status === 'cancelled') {
                    throw new ConflictHttpException('Tugas sudah dibatalkan.');
                }

                $baseVersion = (int) ($input['base_version'] ?? 0);
                if ((int) $run->version !== $baseVersion) {
                    throw new ConflictHttpException((string) $run->version);
                }

                $status = (string) $input['status'];
                $notes = $input['notes'] ?? null;
                $checklistValues = $input['checklist_values'] ?? [];

                $id = (string) ($input['id'] ?? Str::uuid());

                DB::table('task_results')->insert([
                    'id' => $id,
                    'task_run_id' => $runId,
                    'actor_id' => $actor->actorId,
                    'status' => $status,
                    'notes' => $notes,
                    'checklist_values' => json_encode($checklistValues),
                    'accepted_at' => now(),
                ]);

                // A note keeps the run open; only 'completed' closes it.
                $newVersion = (int) $run->version + 1;
                $runUpdate = [
                    'status' => $status === 'completed' ? 'completed' : $run->status,
                    'version' => $newVersion,
                    'updated_at' => now(),
                ];

                DB::table('task_runs')->where('id', $runId)->update($runUpdate);

                ChangeWriter::append(
                    $actor,
                    'task_run',
                    $runId,
                    'upsert',
                    array_merge((array) $run, $runUpdate)
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
    public function listResults(ActorScope $actor, string $runId): array
    {
        $run = DB::table('task_runs')
            ->where('id', $runId)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $run) {
            throw new NotFoundHttpException('Tugas tidak ditemukan.');
        }

        if ($actor->isOperator() && (string) $run->assignee_id !== $actor->actorId) {
            throw new NotFoundHttpException('Tugas tidak ditemukan.');
        }

        return DB::table('task_results')
            ->where('task_run_id', $runId)
            ->orderBy('accepted_at')
            ->get()
            ->map(fn ($r) => (array) $r)
            ->toArray();
    }

    private function assertCageInFarm(ActorScope $actor, string $cageId): void
    {
        $exists = DB::table('cages')
            ->where('id', $cageId)
            ->where('farm_id', $actor->farmId)
            ->exists();

        if (! $exists) {
            throw new UnprocessableEntityHttpException('Kandang tidak ditemukan di farm ini.');
        }
    }

    private function assertAssigneeAuthorized(ActorScope $actor, string $assigneeId): void
    {
        $member = DB::table('memberships')
            ->where('farm_id', $actor->farmId)
            ->where('user_id', $assigneeId)
            ->where('active', true)
            ->exists();

        if (! $member) {
            throw new UnprocessableEntityHttpException('Petugas tidak berizin di farm ini.');
        }
    }

    /**
     * @param  array<string, mixed>  $row
     * @return array<string, mixed>
     */
    private function presentRun(array $row): array
    {
        $snapshot = $row['snapshot'] ? json_decode((string) $row['snapshot'], true) : [];

        return [
            'id' => $row['id'],
            'farm_id' => $row['farm_id'],
            'template_id' => $row['template_id'],
            'cage_id' => $row['cage_id'],
            'business_date' => $row['business_date'],
            'scheduled_at' => $snapshot['scheduled_at'] ?? null,
            'title' => $snapshot['title'] ?? '',
            'sop' => $snapshot['sop'] ?? '',
            'assignee_id' => $row['assignee_id'],
            'status' => $row['status'],
            'latest_note' => $snapshot['latest_note'] ?? null,
            'checklist_items' => $snapshot['checklist_items'] ?? [],
            'version' => $row['version'],
            'updated_at' => $row['updated_at'],
        ];
    }
}
