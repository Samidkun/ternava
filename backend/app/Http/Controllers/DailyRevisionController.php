<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Daily\DailyPolicy;
use App\Daily\ReviseDaily;
use App\Support\ActorScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\HttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class DailyRevisionController extends Controller
{
    public function __construct(
        protected ReviseDaily $reviseDaily
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

    public function index(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);

        $record = DB::table('daily_records')
            ->where('id', $id)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $record) {
            throw new NotFoundHttpException('Catatan harian tidak ditemukan.');
        }

        DailyPolicy::authorizeFlockAccess($actor, (string) $record->flock_id);

        $revisions = DB::table('daily_revisions')
            ->where('daily_record_id', $id)
            ->orderBy('version')
            ->get()
            ->map(fn ($r) => (array) $r)
            ->toArray();

        return response()->json(['data' => $revisions]);
    }

    public function store(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            throw new BadRequestHttpException('Header Idempotency-Key wajib disertakan.');
        }

        $validated = $request->validate([
            'base_version' => ['required', 'integer', 'min:1'],
            'flock_id' => ['required', 'string', 'uuid'],
            'business_date' => ['required', 'date'],
            'feed_type_id' => ['required', 'string', 'uuid'],
            'feed_kg' => ['required', 'string', 'regex:/^(0|[1-9][0-9]{0,11})\.[0-9]{2}$/'],
            'eggs_count' => ['required', 'integer', 'min:0'],
            'mortality_count' => ['nullable', 'integer', 'min:0'],
            'condition' => ['nullable', 'string', 'in:normal,anomaly,sick,molting,not_checked,no_finding,finding'],
            'notes' => ['nullable', 'string', 'max:2000'],
            'reason' => ['required', 'string', 'max:500'],
        ]);

        try {
            $ack = $this->reviseDaily->handle($actor, $id, $validated, (string) $key);

            return response()->json(['data' => $ack->toArray()]);
        } catch (ConflictHttpException $e) {
            $currentVersion = is_numeric($e->getMessage()) ? (int) $e->getMessage() : null;

            return response()->json([
                'error' => [
                    'code' => 'VERSION_CONFLICT',
                    'message' => 'Versi catatan telah berubah di server. Muat ulang sebelum merevisi.',
                    'current_version' => $currentVersion,
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
