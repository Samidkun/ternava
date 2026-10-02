<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('uploads', function (Request $request): Limit {
            $max = (int) config('ternava.limits.upload_per_minute', 10);

            return Limit::perMinute($max)->by((string) $request->user()?->getAuthIdentifier());
        });

        RateLimiter::for('exports', function (Request $request): Limit {
            $max = (int) config('ternava.limits.export_per_minute', 3);

            return Limit::perMinute($max)->by((string) $request->user()?->getAuthIdentifier());
        });
    }
}
