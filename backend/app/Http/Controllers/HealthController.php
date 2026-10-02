<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Throwable;

class HealthController extends Controller
{
    public function live(): JsonResponse
    {
        return response()->json([
            'data' => [
                'status' => 'ok',
                'checked_at' => now()->toISOString(),
            ],
        ]);
    }

    public function ready(): JsonResponse
    {
        $dbOk = true;
        try {
            if (config('database.default') !== 'sqlite' && config('app.env') !== 'testing') {
                DB::connection()->getPdo();
            }
        } catch (Throwable $e) {
            $dbOk = false;
        }

        $storageOk = true;
        try {
            Storage::disk('local')->put('.health_check', 'ok');
            Storage::disk('local')->delete('.health_check');
        } catch (Throwable $e) {
            $storageOk = false;
        }

        if (! $dbOk || ! $storageOk) {
            return response()->json([
                'error' => [
                    'code' => 'SERVICE_UNAVAILABLE',
                    'message' => 'Service dependencies are not ready',
                    'request_id' => (string) str()->uuid(),
                    'retryable' => true,
                ],
            ], 503);
        }

        return response()->json([
            'data' => [
                'status' => 'ok',
                'checked_at' => now()->toISOString(),
            ],
        ]);
    }
}
