<?php

use App\Http\Controllers\CageController;
use App\Http\Controllers\DailyController;
use App\Http\Controllers\DailyRevisionController;
use App\Http\Controllers\FarmController;
use App\Http\Controllers\FeedController;
use App\Http\Controllers\FlockController;
use App\Http\Controllers\HealthController;
use App\Http\Controllers\MemberController;
use App\Http\Controllers\SessionController;
use App\Http\Middleware\RequirePasswordChange;
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

        // Farm endpoints
        Route::get('/farm', [FarmController::class, 'show'])->name('farm.show');
        Route::patch('/farm', [FarmController::class, 'update'])->name('farm.update');

        // Cage endpoints
        Route::get('/cages', [CageController::class, 'index'])->name('cages.index');
        Route::post('/cages', [CageController::class, 'store'])->name('cages.store');
        Route::get('/cages/{id}', [CageController::class, 'show'])->name('cages.show');
        Route::patch('/cages/{id}', [CageController::class, 'update'])->name('cages.update');

        // Flock endpoints
        Route::get('/flocks', [FlockController::class, 'index'])->name('flocks.index');
        Route::post('/flocks', [FlockController::class, 'store'])->name('flocks.store');
        Route::get('/flocks/{id}', [FlockController::class, 'show'])->name('flocks.show');
        Route::patch('/flocks/{id}', [FlockController::class, 'update'])->name('flocks.update');

        // Member endpoints
        Route::get('/members', [MemberController::class, 'index'])->name('members.index');
        Route::post('/members', [MemberController::class, 'store'])->name('members.store');
        Route::get('/members/{id}', [MemberController::class, 'show'])->name('members.show');
        Route::patch('/members/{id}', [MemberController::class, 'update'])->name('members.update');

        // Feed endpoints
        Route::get('/feed-types', [FeedController::class, 'listTypes'])->name('feed_types.index');
        Route::post('/feed-types', [FeedController::class, 'storeType'])->name('feed_types.store');
        Route::get('/feed-types/{id}', [FeedController::class, 'showType'])->name('feed_types.show');
        Route::patch('/feed-types/{id}', [FeedController::class, 'updateType'])->name('feed_types.update');
        Route::get('/feed-balances', [FeedController::class, 'listBalances'])->name('feed_balances.index');
        Route::get('/feed-entries', [FeedController::class, 'listEntries'])->name('feed_entries.index');
        Route::post('/feed-entries', [FeedController::class, 'storeEntry'])->name('feed_entries.store');

        // Daily records endpoints
        Route::get('/daily-records', [DailyController::class, 'index'])->name('daily_records.index');
        Route::post('/daily-records', [DailyController::class, 'store'])->name('daily_records.store');
        Route::get('/daily-records/{id}', [DailyController::class, 'show'])->name('daily_records.show');
        Route::get('/daily-records/{id}/revisions', [DailyRevisionController::class, 'index'])->name('daily_records.revisions.index');
        Route::post('/daily-records/{id}/revisions', [DailyRevisionController::class, 'store'])->name('daily_records.revisions.store');
    });
});
