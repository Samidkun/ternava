<?php

use App\Http\Controllers\HealthController;
use App\Support\WireValidator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/health/live', [HealthController::class, 'live'])->name('api.health.live');
Route::get('/health/ready', [HealthController::class, 'ready'])->name('api.health.ready');

Route::prefix('v1')->group(function () {
    Route::post('/daily-records', function (Request $request) {
        $feedKg = $request->input('feed_kg');
        WireValidator::requireKg($feedKg, 'feed_kg');

        return response()->json([
            'data' => [
                'status' => 'accepted',
            ],
        ]);
    });
});
