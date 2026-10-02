<?php

use App\Http\Controllers\HealthController;
use App\Http\Controllers\SessionController;
use App\Http\Middleware\RequirePasswordChange;
use App\Support\WireValidator;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/health/live', [HealthController::class, 'live'])->name('api.health.live');
Route::get('/health/ready', [HealthController::class, 'ready'])->name('api.health.ready');

Route::prefix('v1')->group(function () {
    // Unauthenticated session endpoints
    Route::post('/session', [SessionController::class, 'login'])->name('session.login');
    Route::post('/auth/login', [SessionController::class, 'login'])->name('auth.login');

    // Authenticated session & business endpoints
    Route::middleware(['auth:sanctum', RequirePasswordChange::class])->group(function () {
        Route::get('/session', [SessionController::class, 'session'])->name('session.show');
        Route::get('/auth/session', [SessionController::class, 'session'])->name('auth.session');

        Route::post('/account/password', [SessionController::class, 'changePassword'])->name('account.password');
        Route::post('/auth/change-password', [SessionController::class, 'changePassword'])->name('auth.change_password');

        Route::delete('/session', [SessionController::class, 'logout'])->name('session.destroy');
        Route::post('/auth/logout', [SessionController::class, 'logout'])->name('auth.logout');

        // Business endpoints guarded by password change requirement
        Route::get('/cages', function () {
            return response()->json(['data' => []]);
        })->name('cages.index');

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
});
