<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Daily\CreateDaily;
use App\Support\ActorScope;
use App\Sync\CursorCodec;
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

        // Contract (openapi listDaily): limit 1..100 (default 50), opaque
        // cursor, and from/to date filters. Without these the endpoint returned
        // every row in the farm (the T44 load benchmark caught it).
        $validated = $request->validate([
            'limit' => ['nullable', 'integer', 'min:1', 'max:100'],
            'cursor' => ['nullable', 'string', 'min:1', 'max:2048'],
            'from' => ['nullable', 'date'],
            'to' => ['nullable', 'date'],
            'flock_id' => ['nullable', 'string', 'uuid'],
            'cage_id' => ['nullable', 'string', 'uuid'],
        ]);

        $limit = (int) ($validated['limit'] ?? 50);

        // Cursor binds the query shape so a page cannot silently change scope.
        $from = $validated['from'] ?? null;
        $to = $validated['to'] ?? null;
        $flockId = $validated['flock_id'] ?? null;
        $cageId = $validated['cage_id'] ?? null;

        $q = DB::table('daily_records')
            ->join('flocks', 'daily_records.flock_id', '=', 'flocks.id')
            ->where('daily_records.farm_id', $actor->farmId);

        if ($actor->isOperator()) {
            $q->whereIn('flocks.cage_id', $actor->cageIds);
        }

        if ($cageId !== null) {
            $q->where('flocks.cage_id', $cageId);
        }

        if ($flockId !== null) {
            $q->where('daily_records.flock_id', $flockId);
        }

        if ($from !== null) {
            $q->where('daily_records.business_date', '>=', $from);
        }

        if ($to !== null) {
            $q->where('daily_records.business_date', '<=', $to);
        }

        // Keyset pagination on the (business_date DESC, id DESC) ordering, which
        // is stable and matches the index on (farm_id, business_date).
        $scope = [
            'farm_id' => $actor->farmId,
            'actor_id' => $actor->actorId,
            'from' => $from,
            'to' => $to,
            'flock_id' => $flockId,
            'cage_id' => $cageId,
        ];

        if (! empty($validated['cursor'])) {
            $claims = CursorCodec::decode((string) $validated['cursor']);
            if (($claims['scope'] ?? null) !== $scope) {
                throw new ConflictHttpException('CURSOR_RESET_REQUIRED: Filter berubah sejak cursor dibuat.');
            }
            $afterDate = (string) $claims['after_date'];
            $afterId = (string) $claims['after_id'];
            $q->where(function ($w) use ($afterDate, $afterId) {
                $w->where('daily_records.business_date', '<', $afterDate)
                    ->orWhere(function ($w2) use ($afterDate, $afterId) {
                        $w2->where('daily_records.business_date', '=', $afterDate)
                            ->where('daily_records.id', '<', $afterId);
                    });
            });
        }

        // Fetch one extra row to learn whether a further page exists.
        $rows = $q->orderByDesc('daily_records.business_date')
            ->orderByDesc('daily_records.id')
            ->limit($limit + 1)
            ->select('daily_records.*')
            ->get();

        $hasMore = $rows->count() > $limit;
        $page = $rows->take($limit)->map(fn ($r) => (array) $r)->values()->toArray();

        $nextCursor = null;
        if ($hasMore && $page !== []) {
            $last = $page[array_key_last($page)];
            $nextCursor = CursorCodec::encode([
                'scope' => $scope,
                'after_date' => $last['business_date'],
                'after_id' => $last['id'],
                'expires_at' => now()->addMinutes(15)->timestamp,
            ]);
        }

        return response()->json([
            'data' => $page,
            'meta' => [
                'next_cursor' => $nextCursor,
                'has_more' => $hasMore,
                'as_of' => now()->toISOString(),
            ],
        ]);
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
