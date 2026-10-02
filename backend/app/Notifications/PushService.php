<?php

declare(strict_types=1);

namespace App\Notifications;

use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Throwable;

/**
 * Best-effort push delivery. Failures are swallowed (and recorded) so that a
 * dead FCM token or a provider outage never rolls back the durable inbox item
 * or any business state.
 */
class PushService
{
    public const MAX_ATTEMPTS = 5;

    public const RETRY_WINDOW_MINUTES = 15;

    /**
     * Build the generic FCM payload. It carries only identifiers — never the
     * physical observation text — so a push can never leak farm details.
     *
     * @return array<string, mixed>
     */
    public function buildPayload(string $eventId): array
    {
        $event = DB::table('notification_outbox')->where('id', $eventId)->first();
        if (! $event) {
            return [];
        }

        return [
            'event_id' => (string) $event->id,
            'kind' => (string) $event->event_kind,
            'resource_id' => (string) $event->resource_id,
        ];
    }

    public function send(string $userId, string $eventId): void
    {
        $devices = DB::table('push_devices')
            ->where('user_id', $userId)
            ->where('enabled', true)
            ->get();

        if ($devices->isEmpty()) {
            // No device / permission denied is a normal state, not an error.
            return;
        }

        $payload = $this->buildPayload($eventId);

        foreach ($devices as $device) {
            if ($this->shouldFail()) {
                // A failed push keeps the device but records nothing fatal.
                continue;
            }

            try {
                $token = Crypt::decryptString((string) $device->fcm_token_encrypted);
                $this->dispatch($token, $payload);
            } catch (Throwable) {
                // A dead/invalid token disables the device but is not fatal.
                DB::table('push_devices')
                    ->where('id', $device->id)
                    ->update(['enabled' => false, 'updated_at' => now()]);
            }
        }
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    protected function dispatch(string $token, array $payload): void
    {
        // In the pilot this is where a real FCM call would go. It is a no-op
        // by default so tests and offline runs stay deterministic.
    }

    private function shouldFail(): bool
    {
        return (bool) config('services.fcm.force_fail', false);
    }
}
