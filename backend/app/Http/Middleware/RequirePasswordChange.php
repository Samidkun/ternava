<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RequirePasswordChange
{
    /**
     * Handle an incoming request.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && $user->must_change_password) {
            $path = $request->path();

            // Whitelisted paths during password change requirement
            if (
                ! str_contains($path, 'session') &&
                ! str_contains($path, 'password') &&
                ! str_contains($path, 'logout')
            ) {
                return response()->json([
                    'error' => [
                        'code' => 'PASSWORD_CHANGE_REQUIRED',
                        'message' => 'Ganti kata sandi sebelum melanjutkan.',
                        'retryable' => false,
                    ],
                ], 403);
            }
        }

        return $next($request);
    }
}
