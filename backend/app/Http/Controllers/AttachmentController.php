<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Attachments\AttachmentService;
use App\Support\ActorScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;

class AttachmentController extends Controller
{
    public function __construct(
        protected AttachmentService $attachmentService
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

    public function store(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $this->requireKey($request);

        $validated = $request->validate([
            'id' => ['nullable', 'string', 'uuid'],
            'parent_type' => ['required', 'string', 'in:daily,incident'],
            'parent_id' => ['required', 'string', 'uuid'],
            'sha256' => ['required', 'string', 'regex:/^[a-f0-9]{64}$/'],
            'file' => ['required', 'file', 'max:2048'],
        ]);

        $ack = $this->attachmentService->upload($actor, $validated, $key, $request->file('file'));

        return response()->json(['data' => $ack->toArray()], 201);
    }

    public function index(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);

        return response()->json(['data' => $this->attachmentService->list($actor, $request->query())]);
    }

    public function download(Request $request, string $id): StreamedResponse
    {
        $actor = $this->getActor($request);

        return $this->attachmentService->download($actor, $id);
    }

    private function requireKey(Request $request): string
    {
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            throw new BadRequestHttpException('Header Idempotency-Key wajib disertakan.');
        }

        return (string) $key;
    }
}
