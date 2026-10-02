<?php

declare(strict_types=1);

namespace App\Incidents;

use App\Contracts\Dto\Ack;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use App\Support\MutationExecutor;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class IncidentService
{
    public function __construct(
        protected IncidentPolicy $policy
    ) {}

    /**
     * @param  array<string, mixed>  $query
     * @return array<int, array<string, mixed>>
     */
    public function list(ActorScope $actor, array $query = []): array
    {
        $q = DB::table('incidents')->where('farm_id', $actor->farmId);

        if ($actor->isOperator()) {
            // Operators only see incidents assigned to them.
            $q->where('assignee_id', $actor->actorId);
        }

        if (isset($query['status'])) {
            $q->where('status', $query['status']);
        }

        if (isset($query['cage_id'])) {
            $q->where('cage_id', $query['cage_id']);
        }

        return $q->orderByDesc('updated_at')
            ->get()
            ->map(fn ($r) => $this->present((array) $r))
            ->toArray();
    }

    /**
     * @return array<string, mixed>
     */
    public function get(ActorScope $actor, string $id): array
    {
        $incident = $this->findScoped($actor, $id);

        if (! $this->policy->canAct($actor, $incident)) {
            throw new NotFoundHttpException('Temuan tidak ditemukan.');
        }

        return $this->present($incident);
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function create(ActorScope $actor, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'POST',
            '/api/v1/incidents',
            $input,
            function () use ($actor) {
                if ($actor->isOperator()) {
                    throw new AccessDeniedHttpException('Operator tidak memiliki izin mencatat temuan.');
                }
            },
            function () use ($actor, $input) {
                $cageId = (string) $input['cage_id'];
                $this->assertCageInFarm($actor, $cageId);

                $flockId = $input['flock_id'] ?? null;
                if ($flockId !== null) {
                    $this->assertFlockInFarm($actor, (string) $flockId);
                }

                $sourceId = $input['source_daily_record_id'] ?? null;
                if ($sourceId !== null) {
                    $this->assertAcceptedDailyInFarm($actor, (string) $sourceId);
                }

                $id = (string) ($input['id'] ?? Str::uuid());
                $data = [
                    'id' => $id,
                    'farm_id' => $actor->farmId,
                    'cage_id' => $cageId,
                    'flock_id' => $flockId,
                    'source_daily_record_id' => $sourceId,
                    'observed_at' => (string) $input['observed_at'],
                    'observation' => trim((string) $input['observation']),
                    'attention' => (string) $input['attention'],
                    'assignee_id' => null,
                    'status' => 'open',
                    'version' => 1,
                    'recorded_by' => $actor->actorId,
                    'accepted_at' => now(),
                    'updated_at' => now(),
                ];

                DB::table('incidents')->insert($data);

                ChangeWriter::append($actor, 'incident', $id, 'upsert', $data);

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
    public function assign(ActorScope $actor, string $id, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'POST',
            "/api/v1/incidents/{$id}/assignment",
            $input,
            function () use ($actor) {
                if (! $this->policy->canAssign($actor)) {
                    throw new AccessDeniedHttpException('Hanya pengelola yang dapat menetapkan petugas.');
                }
            },
            function () use ($actor, $id, $input) {
                $incident = $this->findScoped($actor, $id);

                if ((string) $incident['status'] === 'closed') {
                    throw new ConflictHttpException((string) $incident['version']);
                }

                $baseVersion = (int) ($input['base_version'] ?? 0);
                if ((int) $incident['version'] !== $baseVersion) {
                    throw new ConflictHttpException((string) $incident['version']);
                }

                $assigneeId = (string) $input['assignee_id'];
                $this->assertAssigneeAuthorized($actor, $assigneeId);

                $newVersion = (int) $incident['version'] + 1;
                DB::table('incidents')->where('id', $id)->update([
                    'assignee_id' => $assigneeId,
                    'version' => $newVersion,
                    'updated_at' => now(),
                ]);

                $this->recordAction($actor, $id, 'assign', 'Ditugaskan ke petugas', (string) $incident['status']);

                $updated = $this->findScoped($actor, $id);
                ChangeWriter::append($actor, 'incident', $id, 'upsert', $this->present($updated));

                return Ack::fromArray([
                    'status' => 'accepted',
                    'id' => $id,
                    'version' => $newVersion,
                ]);
            }
        );
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function action(ActorScope $actor, string $id, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'POST',
            "/api/v1/incidents/{$id}/actions",
            $input,
            function () use ($actor, $id) {
                $incident = $this->findScoped($actor, $id);
                if (! $this->policy->canAct($actor, $incident)) {
                    throw new AccessDeniedHttpException('Anda tidak berizin menindak temuan ini.');
                }
            },
            function () use ($actor, $id, $input) {
                $incident = $this->findScoped($actor, $id);

                // A closed incident is immutable.
                if ((string) $incident['status'] === 'closed') {
                    throw new ConflictHttpException((string) $incident['version']);
                }

                $baseVersion = (int) ($input['base_version'] ?? 0);
                if ((int) $incident['version'] !== $baseVersion) {
                    throw new ConflictHttpException((string) $incident['version']);
                }

                $status = (string) $input['status'];
                $notes = trim((string) ($input['notes'] ?? ''));

                if ($status === 'closed' && $notes === '') {
                    throw ValidationException::withMessages([
                        'notes' => ['Jelaskan tindakan sebelum menutup temuan.'],
                    ]);
                }

                $newVersion = (int) $incident['version'] + 1;
                DB::table('incidents')->where('id', $id)->update([
                    'status' => $status,
                    'version' => $newVersion,
                    'updated_at' => now(),
                ]);

                $actionId = (string) ($input['id'] ?? Str::uuid());
                $this->recordAction($actor, $id, $status === 'closed' ? 'close' : 'action', $notes, $status, $actionId);

                $updated = $this->findScoped($actor, $id);
                ChangeWriter::append($actor, 'incident', $id, 'upsert', $this->present($updated));

                return Ack::fromArray([
                    'status' => 'accepted',
                    'id' => $actionId,
                    'version' => $newVersion,
                ]);
            }
        );
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function listActions(ActorScope $actor, string $id): array
    {
        $incident = $this->findScoped($actor, $id);
        if (! $this->policy->canAct($actor, $incident)) {
            throw new NotFoundHttpException('Temuan tidak ditemukan.');
        }

        return DB::table('incident_actions')
            ->where('incident_id', $id)
            ->orderBy('accepted_at')
            ->get()
            ->map(fn ($r) => (array) $r)
            ->toArray();
    }

    private function recordAction(
        ActorScope $actor,
        string $incidentId,
        string $kind,
        string $notes,
        string $status,
        ?string $id = null
    ): void {
        DB::table('incident_actions')->insert([
            'id' => $id ?? (string) Str::uuid(),
            'incident_id' => $incidentId,
            'actor_id' => $actor->actorId,
            'action_kind' => $kind,
            'notes' => $notes,
            'status' => $status,
            'accepted_at' => now(),
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function findScoped(ActorScope $actor, string $id): array
    {
        $row = DB::table('incidents')
            ->where('id', $id)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $row) {
            throw new NotFoundHttpException('Temuan tidak ditemukan.');
        }

        return (array) $row;
    }

    /**
     * @param  array<string, mixed>  $row
     * @return array<string, mixed>
     */
    private function present(array $row): array
    {
        return [
            'id' => $row['id'],
            'farm_id' => $row['farm_id'],
            'cage_id' => $row['cage_id'],
            'flock_id' => $row['flock_id'],
            'source_daily_record_id' => $row['source_daily_record_id'],
            'observed_at' => $row['observed_at'],
            'observation' => $row['observation'],
            'attention' => $row['attention'],
            'assignee_id' => $row['assignee_id'],
            'status' => $row['status'],
            'version' => $row['version'],
            'updated_at' => $row['updated_at'],
        ];
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

    private function assertFlockInFarm(ActorScope $actor, string $flockId): void
    {
        $exists = DB::table('flocks')
            ->where('id', $flockId)
            ->where('farm_id', $actor->farmId)
            ->exists();

        if (! $exists) {
            throw new UnprocessableEntityHttpException('Kelompok tidak ditemukan di farm ini.');
        }
    }

    private function assertAcceptedDailyInFarm(ActorScope $actor, string $sourceId): void
    {
        $exists = DB::table('daily_records')
            ->where('id', $sourceId)
            ->where('farm_id', $actor->farmId)
            ->exists();

        if (! $exists) {
            throw new UnprocessableEntityHttpException('Catatan harian sumber tidak ditemukan di farm ini.');
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
}
