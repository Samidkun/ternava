<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * Contract-level abuse guards applied to every authenticated API request:
 * JSON body size (64 KiB) and the authenticated rate budget (120/min). Route
 * specific upload/export budgets are named rate limiters registered in
 * AppServiceProvider and attached with the `throttle` middleware.
 */
final class RequestLimits
{
    public function handle(Request $request, Closure $next): Response
    {
        $this->assertJsonBodyWithinLimit($request);

        if ($request->user()) {
            $key = 'auth:'.$request->user()->getAuthIdentifier();
            $max = (int) config('ternava.limits.auth_per_minute', 120);

            if (RateLimiter::tooManyAttempts($key, $max)) {
                return $this->tooManyRequestsResponse((string) RateLimiter::availableIn($key));
            }

            RateLimiter::hit($key, 60);
        }

        return $next($request);
    }

    private function assertJsonBodyWithinLimit(Request $request): void
    {
        if (! $request->isJson()) {
            return;
        }

        $max = (int) config('ternava.limits.json_body_bytes', 65536);
        $declared = (int) $request->header('Content-Length', '0');

        if ($declared > $max) {
            throw new HttpException(413, 'Ukuran JSON melebihi batas 64 KiB.');
        }

        $raw = $request->getContent();

        if ($raw !== '' && strlen($raw) > $max) {
            throw new HttpException(413, 'Ukuran JSON melebihi batas 64 KiB.');
        }
    }

    private function tooManyRequestsResponse(string $retryAfter): JsonResponse
    {
        return new JsonResponse([
            'error' => [
                'code' => 'RATE_LIMITED',
                'message' => 'Terlalu banyak permintaan. Coba lagi nanti.',
                'retryable' => true,
            ],
        ], 429, ['Retry-After' => $retryAfter]);
    }
}
