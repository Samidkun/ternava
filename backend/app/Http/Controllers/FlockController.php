<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Flocks\FlockService;
use App\Support\ActorScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;

class FlockController extends Controller
{
    public function __construct(
        protected FlockService $flockService
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
        $flocks = $this->flockService->list($actor, $request->query());

        return response()->json(['data' => $flocks]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $flock = $this->flockService->get($actor, $id);

        return response()->json(['data' => $flock]);
    }

    public function store(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            throw new BadRequestHttpException('Header Idempotency-Key wajib disertakan.');
        }

        $validated = $request->validate([
            'id' => ['nullable', 'string', 'uuid'],
            'cage_id' => ['required', 'string', 'uuid'],
            'code' => ['required', 'string', 'max:32'],
            'placed_on' => ['required', 'date'],
            'finished_on' => ['nullable', 'date', 'after_or_equal:placed_on'],
            'initial_population' => ['required', 'integer', 'min:1', 'max:1000000'],
            'status' => ['required', 'string', 'in:active,finished'],
        ]);

        $ack = $this->flockService->create($actor, $validated, (string) $key);

        return response()->json(['data' => $ack->toArray()]);
    }

    public function update(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            throw new BadRequestHttpException('Header Idempotency-Key wajib disertakan.');
        }

        $validated = $request->validate([
            'base_version' => ['nullable', 'integer'],
            'code' => ['nullable', 'string', 'max:32'],
            'status' => ['nullable', 'string', 'in:active,finished'],
            'finished_on' => ['nullable', 'date'],
            'initial_population' => ['nullable', 'integer', 'min:1'],
            'reason' => ['required', 'string', 'max:500'],
        ]);

        $ack = $this->flockService->update($actor, $id, $validated, (string) $key);

        return response()->json(['data' => $ack->toArray()]);
    }
}
