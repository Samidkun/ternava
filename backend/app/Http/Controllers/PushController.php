<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Support\ActorScope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;

class PushController extends Controller
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

    public function register(Request $request): JsonResponse
    {
        $actor = $this->getActor($request);

        $validated = $request->validate([
            'device_id' => ['required', 'string', 'uuid'],
            'fcm_token' => ['required', 'string', 'min:1', 'max:4096'],
            'enabled' => ['required', 'boolean'],
        ]);

        $deviceId = (string) $validated['device_id'];

        // The token is encrypted at rest; it is never returned to a client.
        $encrypted = Crypt::encryptString((string) $validated['fcm_token']);

        $existing = DB::table('push_devices')
            ->where('user_id', $actor->actorId)
            ->where('device_id', $deviceId)
            ->first();

        if ($existing) {
            DB::table('push_devices')
                ->where('id', $existing->id)
                ->update([
                    'fcm_token_encrypted' => $encrypted,
                    'enabled' => (bool) $validated['enabled'],
                    'updated_at' => now(),
                ]);
        } else {
            DB::table('push_devices')->insert([
                'id' => (string) Str::uuid(),
                'farm_id' => $actor->farmId,
                'user_id' => $actor->actorId,
                'device_id' => $deviceId,
                'fcm_token_encrypted' => $encrypted,
                'enabled' => (bool) $validated['enabled'],
                'updated_at' => now(),
            ]);
        }

        return response()->json(['data' => [
            'device_id' => $deviceId,
            'enabled' => (bool) $validated['enabled'],
            'updated_at' => now()->toIso8601String(),
        ]]);
    }

    public function unregister(Request $request, string $id): JsonResponse
    {
        $actor = $this->getActor($request);

        DB::table('push_devices')
            ->where('device_id', $id)
            ->where('user_id', $actor->actorId)
            ->delete();

        return response()->json(null, 204);
    }
}
