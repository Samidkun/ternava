<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Support\ActorScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\BadRequestHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class InboxController extends Controller
{
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

        return new ActorScope(
            actorId: (string) $user->id,
            farmId: (string) $membership->farm_id,
            role: (string) $membership->role
        );
    }

    public function index(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);

        $items = DB::table('inbox_items')
            ->where('user_id', $actor->actorId)
            ->orderByDesc('updated_at')
            ->get()
            ->map(fn ($row) => $this->present((array) $row))
            ->toArray();

        return response()->json(['data' => $items]);
    }

    public function read(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            throw new BadRequestHttpException('Header Idempotency-Key wajib disertakan.');
        }

        // An inbox item is private to its owner; a foreign id is not found.
        $item = DB::table('inbox_items')
            ->where('id', $id)
            ->where('user_id', $actor->actorId)
            ->first();

        if (! $item) {
            throw new NotFoundHttpException('Notifikasi tidak ditemukan.');
        }

        if ($item->read_at === null) {
            DB::table('inbox_items')
                ->where('id', $id)
                ->update([
                    'read_at' => now(),
                    'version' => (int) $item->version + 1,
                    'updated_at' => now(),
                ]);
        }

        return response()->json(['data' => ['status' => 'accepted', 'id' => $id]]);
    }

    /**
     * @param  array<string, mixed>  $row
     * @return array<string, mixed>
     */
    private function present(array $row): array
    {
        $payload = json_decode((string) $row['payload'], true) ?: [];

        return [
            'id' => $row['id'],
            'version' => (int) $row['version'],
            'updated_at' => $row['updated_at'],
            'kind' => $payload['kind'] ?? 'incident',
            'title' => $payload['title'] ?? 'Pemberitahuan',
            'body' => $payload['body'] ?? '',
            'resource_type' => $payload['resource_type'] ?? 'incident',
            'resource_id' => $payload['resource_id'] ?? '',
            'read_at' => $row['read_at'],
        ];
    }
}
