<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\FarmAccess\MemberService;
use App\Support\ActorScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;

class MemberController extends Controller
{
    public function __construct(
        protected MemberService $memberService
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
        $members = $this->memberService->list($actor, $request->query());

        return response()->json(['data' => $members]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $member = $this->memberService->get($actor, $id);

        return response()->json(['data' => $member]);
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
            'username' => ['required', 'string', 'max:80'],
            'display_name' => ['required', 'string', 'max:100'],
            'role' => ['required', 'string', 'in:admin,operator'],
            'cage_ids' => ['required', 'array'],
            'cage_ids.*' => ['string', 'uuid'],
            'active' => ['required', 'boolean'],
            'temporary_password' => ['required', 'string', 'min:12'],
        ]);

        $ack = $this->memberService->create($actor, $validated, (string) $key);

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
            'display_name' => ['nullable', 'string', 'max:100'],
            'role' => ['nullable', 'string', 'in:admin,operator'],
            'cage_ids' => ['nullable', 'array'],
            'cage_ids.*' => ['string', 'uuid'],
            'active' => ['nullable', 'boolean'],
        ]);

        $ack = $this->memberService->update($actor, $id, $validated, (string) $key);

        return response()->json(['data' => $ack->toArray()]);
    }
}
