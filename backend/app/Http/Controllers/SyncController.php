<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Support\ActorScope;
use App\Sync\SyncService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class SyncController extends Controller
{
    public function __construct(
        protected SyncService $syncService
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

    public function bootstrap(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $cursor = $request->query('cursor');
        $limit = (int) $request->query('limit', '50');

        try {
            $page = $this->syncService->bootstrap($actor, $cursor ? (string) $cursor : null, $limit);

            return response()->json(['data' => $page]);
        } catch (ConflictHttpException $e) {
            return response()->json([
                'error' => [
                    'code' => 'CURSOR_RESET_REQUIRED',
                    'message' => $e->getMessage(),
                    'retryable' => false,
                ],
            ], 409);
        }
    }

    public function changes(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $cursor = $request->query('cursor');
        $limit = (int) $request->query('limit', '50');

        try {
            $page = $this->syncService->changes($actor, $cursor ? (string) $cursor : null, $limit);

            return response()->json(['data' => $page]);
        } catch (ConflictHttpException $e) {
            return response()->json([
                'error' => [
                    'code' => 'CURSOR_RESET_REQUIRED',
                    'message' => $e->getMessage(),
                    'retryable' => false,
                ],
            ], 409);
        }
    }
}
