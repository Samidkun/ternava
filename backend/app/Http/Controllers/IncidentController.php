<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Incidents\IncidentService;
use App\Support\ActorScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class IncidentController extends Controller
{
    public function __construct(
        protected IncidentService $incidentService
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

    public function index(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);

        return response()->json(['data' => $this->incidentService->list($actor, $request->query())]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);

        return response()->json(['data' => $this->incidentService->get($actor, $id)]);
    }

    public function store(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $this->requireKey($request);

        $validated = $request->validate([
            'id' => ['nullable', 'string', 'uuid'],
            'cage_id' => ['required', 'string', 'uuid'],
            'flock_id' => ['nullable', 'string', 'uuid'],
            'observed_at' => ['required', 'date'],
            'observation' => ['required', 'string', 'min:1', 'max:2000'],
            'attention' => ['required', 'string', 'in:routine,priority'],
            'source_daily_record_id' => ['nullable', 'string', 'uuid'],
        ]);

        $ack = $this->incidentService->create($actor, $validated, $key);

        return response()->json(['data' => $ack->toArray()], 201);
    }

    public function assign(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $this->requireKey($request);

        $validated = $request->validate([
            'base_version' => ['required', 'integer', 'min:1'],
            'assignee_id' => ['required', 'string', 'uuid'],
        ]);

        try {
            $ack = $this->incidentService->assign($actor, $id, $validated, $key);

            return response()->json(['data' => $ack->toArray()]);
        } catch (ConflictHttpException $e) {
            return $this->conflict();
        }
    }

    public function storeAction(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $this->requireKey($request);

        $validated = $request->validate([
            'id' => ['nullable', 'string', 'uuid'],
            'base_version' => ['required', 'integer', 'min:1'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'status' => ['required', 'string', 'in:open,in_progress,closed'],
        ]);

        try {
            $ack = $this->incidentService->action($actor, $id, $validated, $key);

            return response()->json(['data' => $ack->toArray()], 201);
        } catch (ConflictHttpException $e) {
            return $this->conflict();
        }
    }

    public function listActions(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);

        return response()->json(['data' => $this->incidentService->listActions($actor, $id)]);
    }

    private function requireKey(Request $request): string
    {
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            throw new BadRequestHttpException('Header Idempotency-Key wajib disertakan.');
        }

        return (string) $key;
    }

    private function conflict(): JsonResponse
    {
        return response()->json([
            'error' => [
                'code' => 'VERSION_CONFLICT',
                'message' => 'Temuan sudah berubah.',
                'retryable' => false,
            ],
        ], 409);
    }
}
