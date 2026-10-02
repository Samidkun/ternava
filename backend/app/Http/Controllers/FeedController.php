<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Feed\FeedService;
use App\Support\ActorScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;
use Symfony\Component\HttpKernel\Exception\HttpException;

class FeedController extends Controller
{
    public function __construct(
        protected FeedService $feedService
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

    public function listTypes(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $types = $this->feedService->listTypes($actor, $request->query());

        return response()->json(['data' => $types]);
    }

    public function showType(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $type = $this->feedService->getType($actor, $id);

        return response()->json(['data' => $type]);
    }

    public function storeType(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            throw new BadRequestHttpException('Header Idempotency-Key wajib disertakan.');
        }

        $validated = $request->validate([
            'id' => ['nullable', 'string', 'uuid'],
            'code' => ['required', 'string', 'max:32'],
            'name' => ['required', 'string', 'max:100'],
            'minimum_kg' => ['nullable', 'string', 'regex:/^(0|[1-9][0-9]{0,11})\.[0-9]{2}$/'],
        ]);

        $ack = $this->feedService->createType($actor, $validated, (string) $key);

        return response()->json(['data' => $ack->toArray()]);
    }

    public function updateType(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            throw new BadRequestHttpException('Header Idempotency-Key wajib disertakan.');
        }

        $validated = $request->validate([
            'name' => ['nullable', 'string', 'max:100'],
            'minimum_kg' => ['nullable', 'string', 'regex:/^(0|[1-9][0-9]{0,11})\.[0-9]{2}$/'],
            'active' => ['nullable', 'boolean'],
        ]);

        $ack = $this->feedService->updateType($actor, $id, $validated, (string) $key);

        return response()->json(['data' => $ack->toArray()]);
    }

    public function listBalances(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $balances = $this->feedService->listBalances($actor);

        return response()->json(['data' => $balances]);
    }

    public function listEntries(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $entries = $this->feedService->listEntries($actor, $request->query());

        return response()->json(['data' => $entries]);
    }

    public function storeEntry(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            throw new BadRequestHttpException('Header Idempotency-Key wajib disertakan.');
        }

        $validated = $request->validate([
            'id' => ['nullable', 'string', 'uuid'],
            'feed_type_id' => ['required', 'string', 'uuid'],
            'business_date' => ['required', 'date'],
            'kind' => ['required', 'string', 'in:opening,receipt,adjustment'],
            'quantity_kg' => ['required', 'string', 'regex:/^(0|[1-9][0-9]{0,11})\.[0-9]{2}$/'],
            'direction' => ['required', 'string', 'in:in,out'],
            'unit_price_idr' => ['nullable', 'string', 'regex:/^(0|[1-9][0-9]{0,15})\.[0-9]{2}$/'],
            'supplier' => ['nullable', 'string', 'max:100'],
            'reason' => ['nullable', 'string', 'max:500'],
        ]);

        try {
            $ack = $this->feedService->createEntry($actor, $validated, (string) $key);

            return response()->json(['data' => $ack->toArray()]);
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
