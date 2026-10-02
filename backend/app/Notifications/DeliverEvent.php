<?php

declare(strict_types=1);

namespace App\Notifications;

use Illuminate\Support\Facades\DB;

/**
 * Turns a durable notification_outbox row into inbox items for every recipient
 * that should see it, then asks PushService to deliver an optional push.
 *
 * The inbox item is written FIRST and is unique per (event, user), so a failed
 * or repeated push can never produce a duplicate inbox entry.
 */
class DeliverEvent
{
    public function __construct(
        protected PushService $pushService
    ) {}

    public function handle(string $eventId): void
    {
        $event = DB::table('notification_outbox')->where('id', $eventId)->first();
        if (! $event) {
            return;
        }

        $payload = json_decode((string) $event->payload, true) ?: [];
        $recipients = $this->recipientsFor($event);

        foreach ($recipients as $userId) {
            // firstOrCreate keeps exactly one inbox item per event+user.
            $existing = DB::table('inbox_items')
                ->where('event_id', $eventId)
                ->where('user_id', $userId)
                ->first();

            if (! $existing) {
                DB::table('inbox_items')->insert([
                    'id' => (string) str()->uuid(),
                    'farm_id' => $event->farm_id,
                    'user_id' => $userId,
                    'event_id' => $eventId,
                    'payload' => json_encode($payload),
                    'read_at' => null,
                    'version' => 1,
                    'updated_at' => now(),
                ]);
            }
        }

        DB::table('notification_outbox')
            ->where('id', $eventId)
            ->update([
                'attempts' => (int) $event->attempts + 1,
                'processed_at' => now(),
            ]);

        // Push is best-effort; a failure must not undo the durable inbox write.
        foreach ($recipients as $userId) {
            $this->pushService->send($userId, $eventId);
        }
    }

    /**
     * @return array<int, string>
     */
    private function recipientsFor(object $event): array
    {
        // Owner(s) of the farm always receive; operators assigned to the
        // resource are added when the payload names an assignee.
        $ownerIds = DB::table('memberships')
            ->where('farm_id', $event->farm_id)
            ->where('role', 'owner')
            ->where('active', true)
            ->pluck('user_id')
            ->map(fn ($id) => (string) $id)
            ->toArray();

        return array_values(array_unique($ownerIds));
    }
}
