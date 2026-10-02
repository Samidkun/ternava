<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\FarmAccess\SessionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\RateLimiter;
use Symfony\Component\HttpKernel\Exception\UnauthorizedHttpException;

class SessionController extends Controller
{
    public function __construct(
        protected SessionService $sessionService
    ) {}

    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'username' => ['required', 'string'],
            'password' => ['required', 'string'],
        ]);

        $throttleKey = 'login:'.strtolower((string) $validated['username']).'|'.$request->ip();

        if (RateLimiter::tooManyAttempts($throttleKey, 5)) {
            $seconds = RateLimiter::availableIn($throttleKey);

            return response()->json([
                'error' => [
                    'code' => 'RATE_LIMIT_EXCEEDED',
                    'message' => 'Terlalu banyak percobaan masuk. Coba lagi dalam '.$seconds.' detik.',
                    'retryable' => false,
                ],
            ], 429)->header('Retry-After', (string) $seconds);
        }

        try {
            $session = $this->sessionService->login($validated);
            RateLimiter::clear($throttleKey);

            return response()->json(['data' => $session]);
        } catch (UnauthorizedHttpException $e) {
            RateLimiter::hit($throttleKey, 60);

            return response()->json([
                'error' => [
                    'code' => 'INVALID_CREDENTIALS',
                    'message' => 'Nama pengguna atau kata sandi tidak cocok.',
                    'retryable' => false,
                ],
            ], 401);
        }
    }

    public function session(Request $request): JsonResponse
    {
        $info = $this->sessionService->session($request->user());

        return response()->json(['data' => $info]);
    }

    public function changePassword(Request $request): Response
    {
        $validated = $request->validate([
            'current_password' => ['required', 'string'],
            'new_password' => ['required', 'string', 'min:8'],
        ]);

        $this->sessionService->changePassword(
            $request->user(),
            (string) $validated['current_password'],
            (string) $validated['new_password']
        );

        return response()->noContent();
    }

    public function logout(Request $request): Response
    {
        $this->sessionService->logout($request->user());

        return response()->noContent();
    }
}
