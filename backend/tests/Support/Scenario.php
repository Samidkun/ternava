<?php

namespace Tests\Support;

use App\Models\User;

class Scenario
{
    /**
     * Layer Farm scenario with 100 chickens, 300.00 kg feed balance, assigned operator.
     *
     * @return array<string, mixed>
     */
    public static function layerFarm(): array
    {
        $owner = new User([
            'id' => (string) str()->uuid(),
            'name' => 'Pak Joko (Owner)',
            'email' => 'owner@ternava.local',
        ]);

        $operator = new User([
            'id' => (string) str()->uuid(),
            'name' => 'Budi (Operator)',
            'email' => 'operator@ternava.local',
        ]);

        $other = new User([
            'id' => (string) str()->uuid(),
            'name' => 'Siti (Other)',
            'email' => 'other@ternava.local',
        ]);

        $farmId = (string) str()->uuid();
        $cageId = (string) str()->uuid();
        $flockId = (string) str()->uuid();
        $feedId = (string) str()->uuid();

        return [
            'farm_id' => $farmId,
            'owner' => $owner,
            'operator' => $operator,
            'other' => $other,
            'cage' => [
                'id' => $cageId,
                'farm_id' => $farmId,
                'code' => 'K-01',
                'name' => 'Kandang Baterai 1',
                'capacity' => 120,
            ],
            'flock' => [
                'id' => $flockId,
                'cage_id' => $cageId,
                'farm_id' => $farmId,
                'code' => 'FL-2026-A',
                'strain' => 'Isa Brown',
                'initial_population' => 100,
                'current_population' => 100,
            ],
            'feed' => [
                'id' => $feedId,
                'farm_id' => $farmId,
                'name' => 'Konsentrat Layer 1',
                'current_stock_kg' => '300.00',
            ],
            'daily' => [
                'farm_id' => $farmId,
                'cage_id' => $cageId,
                'flock_id' => $flockId,
                'date' => now()->format('Y-m-d'),
                'eggs_count' => 85,
                'damaged_eggs_count' => 2,
                'feed_kg' => '12.50',
                'mortality_count' => 0,
            ],
            'incident' => [
                'farm_id' => $farmId,
                'cage_id' => $cageId,
                'flock_id' => $flockId,
                'category' => 'health',
                'severity' => 'warning',
                'description' => 'Ayam terlihat lemas di blok A3',
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public static function secondOwnerRow(User $owner): array
    {
        return [
            'id' => (string) str()->uuid(),
            'farm_id' => (string) str()->uuid(),
            'user_id' => (string) str()->uuid(),
            'role' => 'owner',
            'active' => true,
        ];
    }
}
