<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Support\ActorScope;
use App\Tasks\TaskService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class TaskController extends Controller
{
    public function __construct(
        protected TaskService $taskService
    ) {}

    protected function getActor(Request $request): ActorScope
    {
        $user = $request->user();
        if (! $user) {
            throw new AccessDeniedHttpException('Tidak terautentikasi.');
        }

        $membership = DB::table('memberships')
            ->where('user_id', $user->id)
            ->where('active', true)
            ->first();

        if (! $membership) {
            throw new AccessDeniedHttpException('Pengguna tidak memiliki keanggotaan aktif.');
        }

        $cageIds = DB::table('cage_assignments')
            ->where('membership_id', $membership->id)
            ->pluck('cage_id')
            ->map(fn ($id) => (string) $id)
            ->toArray();

        return new ActorScope(
            actorId: (string) $user->id,
            farmId: (string) $membership->farm_id,
            role: (string) $membership->role,
            cageIds: $cageIds
        );
    }

    public function listTemplates(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);

        return response()->json(['data' => $this->taskService->listTemplates($actor, $request->query())]);
    }

    public function showTemplate(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);

        return response()->json(['data' => $this->taskService->getTemplate($actor, $id)]);
    }

    public function storeTemplate(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $this->requireKey($request);

        $validated = $request->validate([
            'id' => ['nullable', 'string', 'uuid'],
            'cage_id' => ['required', 'string', 'uuid'],
            'title' => ['required', 'string', 'min:1', 'max:120'],
            'kind' => ['required', 'string', 'in:routine,inspection,vaccination'],
            'sop' => ['required', 'string', 'min:1', 'max:2000'],
            'assignee_id' => ['required', 'string', 'uuid'],
            'start_on' => ['required', 'date'],
            'end_on' => ['nullable', 'date', 'after_or_equal:start_on'],
            'local_time' => ['required', 'string', 'regex:/^([01][0-9]|2[0-3]):[0-5][0-9]$/'],
            'recurrence' => ['required', 'string', 'in:once,daily,weekly'],
        ]);

        $ack = $this->taskService->createTemplate($actor, $validated, $key);

        return response()->json(['data' => $ack->toArray()]);
    }

    public function updateTemplate(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $this->requireKey($request);

        $validated = $request->validate([
            'base_version' => ['required', 'integer', 'min:1'],
            'cage_id' => ['required', 'string', 'uuid'],
            'title' => ['required', 'string', 'min:1', 'max:120'],
            'kind' => ['required', 'string', 'in:routine,inspection,vaccination'],
            'sop' => ['required', 'string', 'min:1', 'max:2000'],
            'assignee_id' => ['required', 'string', 'uuid'],
            'start_on' => ['required', 'date'],
            'end_on' => ['nullable', 'date'],
            'local_time' => ['required', 'string', 'regex:/^([01][0-9]|2[0-3]):[0-5][0-9]$/'],
            'recurrence' => ['required', 'string', 'in:once,daily,weekly'],
            'active' => ['required', 'boolean'],
        ]);

        try {
            $ack = $this->taskService->updateTemplate($actor, $id, $validated, $key);

            return response()->json(['data' => $ack->toArray()]);
        } catch (ConflictHttpException $e) {
            return $this->conflict($e);
        }
    }

    public function listRuns(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);

        return response()->json(['data' => $this->taskService->listRuns($actor, $request->query())]);
    }

    public function showRun(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);

        return response()->json(['data' => $this->taskService->getRun($actor, $id)]);
    }

    public function storeResult(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $this->requireKey($request);

        $validated = $request->validate([
            'id' => ['nullable', 'string', 'uuid'],
            'base_version' => ['required', 'integer', 'min:1'],
            'status' => ['required', 'string', 'in:note,completed'],
            'notes' => ['nullable', 'string', 'min:1', 'max:2000'],
            'checklist_values' => ['array', 'max:20'],
            'checklist_values.*.id' => ['required', 'string', 'uuid'],
            'checklist_values.*.checked' => ['required', 'boolean'],
        ]);

        try {
            $ack = $this->taskService->createResult($actor, $id, $validated, $key);

            return response()->json(['data' => $ack->toArray()]);
        } catch (ConflictHttpException $e) {
            return $this->conflict($e);
        }
    }

    public function listResults(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);

        return response()->json(['data' => $this->taskService->listResults($actor, $id)]);
    }

    private function requireKey(Request $request): string
    {
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            throw new BadRequestHttpException('Header Idempotency-Key wajib disertakan.');
        }

        return (string) $key;
    }

    private function conflict(ConflictHttpException $e): JsonResponse
    {
        return response()->json([
            'error' => [
                'code' => 'VERSION_CONFLICT',
                'message' => 'Versi data sudah berubah.',
                'retryable' => false,
            ],
        ], 409);
    }
}
