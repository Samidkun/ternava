<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Daily\CreateDaily;
use App\Support\ActorScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class DailyController extends Controller
{
    public function __construct(
        protected CreateDaily $createDaily
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

        $q = DB::table('daily_records')
            ->join('flocks', 'daily_records.flock_id', '=', 'flocks.id')
            ->where('daily_records.farm_id', $actor->farmId);

        if ($actor->isOperator()) {
            $q->whereIn('flocks.cage_id', $actor->cageIds);
        }

        if ($request->has('flock_id')) {
            $q->where('daily_records.flock_id', $request->query('flock_id'));
        }

        if ($request->has('from_date')) {
            $q->where('daily_records.business_date', '>=', $request->query('from_date'));
        }

        if ($request->has('to_date')) {
            $q->where('daily_records.business_date', '<=', $request->query('to_date'));
        }

        $records = $q->select('daily_records.*')
            ->orderByDesc('daily_records.business_date')
            ->get()
            ->map(fn ($r) => (array) $r)
            ->toArray();

        return response()->json(['data' => $records]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);

        $record = DB::table('daily_records')
            ->join('flocks', 'daily_records.flock_id', '=', 'flocks.id')
            ->where('daily_records.id', $id)
            ->where('daily_records.farm_id', $actor->farmId)
            ->select('daily_records.*', 'flocks.cage_id')
            ->first();

        if (! $record) {
            throw new NotFoundHttpException('Catatan harian tidak ditemukan.');
        }

        if ($actor->isOperator() && ! $actor->canAccessCage((string) $record->cage_id)) {
            throw new NotFoundHttpException('Catatan harian tidak ditemukan.');
        }

        return response()->json(['data' => (array) $record]);
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
            'flock_id' => ['required', 'string', 'uuid'],
            'business_date' => ['required', 'date'],
            'feed_type_id' => ['required', 'string', 'uuid'],
            'feed_kg' => ['required', 'string', 'regex:/^(0|[1-9][0-9]{0,11})\.[0-9]{2}$/'],
            'eggs_count' => ['required', 'integer', 'min:0'],
            'mortality_count' => ['nullable', 'integer', 'min:0'],
            'condition' => ['required', 'string', 'in:normal,anomaly,sick,molting,not_checked,no_finding,finding'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);

        try {
            $ack = $this->createDaily->handle($actor, $validated, (string) $key);

            return response()->json(['data' => $ack->toArray()]);
        } catch (ConflictHttpException $e) {
            return response()->json([
                'error' => [
                    'code' => 'DAILY_ALREADY_EXISTS',
                    'message' => $e->getMessage(),
                    'retryable' => false,
                ],
            ], 409);
        } catch (HttpException $e) {
            if ($e->getStatusCode() === 422) {
                return response()->json([
                    'error' => [
                        'code' => 'INSUFFICIENT_STOCK',
                        'message' => $e->getMessage(),
                        'retryable' => false,
                    ],
                ], 422);
            }

            throw $e;
        }
    }
}
