<?php

namespace Tests\Support;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

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
            'username' => 'owner_scenario',
            'display_name' => 'Pak Joko (Owner)',
            'password_hash' => 'hash',
            'must_change_password' => false,
            'active' => true,
        ]);

        $operator = new User([
            'id' => (string) str()->uuid(),
            'username' => 'operator_scenario',
            'display_name' => 'Budi (Operator)',
            'password_hash' => 'hash',
            'must_change_password' => false,
            'active' => true,
        ]);

        $other = new User([
            'id' => (string) str()->uuid(),
            'username' => 'other_scenario',
            'display_name' => 'Siti (Other)',
            'password_hash' => 'hash',
            'must_change_password' => false,
            'active' => true,
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
                'feed_type_id' => $feedId,
                'business_date' => now()->format('Y-m-d'),
                'eggs_count' => 85,
                'damaged_eggs_count' => 2,
                'feed_kg' => '12.50',
                'mortality_count' => 0,
                'condition' => 'normal',
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
     * @param  array<string, mixed>  $f
     * @return array<string, mixed>
     */
    public static function persist(array $f): array
    {
        DB::table('farms')->insert([
            'id' => $f['farm_id'],
            'name' => 'Farm Skenario Layer',
            'location' => 'Malang',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        $f['owner']->save();
        $f['operator']->save();

        DB::table('memberships')->insert([
            [
                'id' => (string) str()->uuid(),
                'farm_id' => $f['farm_id'],
                'user_id' => $f['owner']->id,
                'role' => 'owner',
                'scope_version' => 1,
                'version' => 1,
                'active' => true,
            ],
        ]);

        $operatorMembershipId = (string) str()->uuid();
        DB::table('memberships')->insert([
            [
                'id' => $operatorMembershipId,
                'farm_id' => $f['farm_id'],
                'user_id' => $f['operator']->id,
                'role' => 'operator',
                'scope_version' => 1,
                'version' => 1,
                'active' => true,
            ],
        ]);

        DB::table('cages')->insert([
            'id' => $f['cage']['id'],
            'farm_id' => $f['farm_id'],
            'code' => $f['cage']['code'],
            'name' => $f['cage']['name'],
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('cage_assignments')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $f['farm_id'],
            'membership_id' => $operatorMembershipId,
            'cage_id' => $f['cage']['id'],
        ]);

        DB::table('flocks')->insert([
            'id' => $f['flock']['id'],
            'farm_id' => $f['farm_id'],
            'cage_id' => $f['cage']['id'],
            'code' => $f['flock']['code'],
            'placed_on' => '2026-01-01',
            'finished_on' => null,
            'initial_population' => 100,
            'recorded_population' => 100,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('feed_types')->insert([
            'id' => $f['feed']['id'],
            'farm_id' => $f['farm_id'],
            'code' => 'FEED-SCENARIO-1',
            'name' => $f['feed']['name'],
            'minimum_kg' => 0.00,
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('feed_balances')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $f['farm_id'],
            'feed_type_id' => $f['feed']['id'],
            'quantity_kg' => $f['feed']['current_stock_kg'],
            'updated_at' => now(),
        ]);

        // A separate farm that 'other' belongs to, so cross-farm access checks
        // exercise a real, unauthorized membership rather than a missing one.
        $otherFarmId = (string) str()->uuid();
        DB::table('farms')->insert([
            'id' => $otherFarmId,
            'name' => 'Farm Lain',
            'location' => 'Surabaya',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        $f['other']->save();
        DB::table('memberships')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $otherFarmId,
            'user_id' => $f['other']->id,
            'role' => 'owner',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        return $f;
    }

    /**
     * @param  array<string, mixed>  $f
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    public static function weeklyTemplate(array $f, array $overrides = []): array
    {
        return array_merge([
            'id' => (string) str()->uuid(),
            'cage_id' => $f['cage']['id'],
            'title' => 'Bersihkan tempat pakan',
            'kind' => 'routine',
            'sop' => "Sikat tempat pakan\nBuang sisa pakan basah\nIsi pakan baru",
            'assignee_id' => $f['operator']->id,
            'start_on' => now()->format('Y-m-d'),
            'end_on' => null,
            'local_time' => '06:30',
            'recurrence' => 'weekly',
        ], $overrides);
    }

    /**
     * Persist a closed incident for the given farm scenario.
     *
     * @param  array<string, mixed>  $f
     */
    public static function closedIncident(array $f): object
    {
        $id = (string) str()->uuid();

        DB::table('incidents')->insert([
            'id' => $id,
            'farm_id' => $f['farm_id'],
            'cage_id' => $f['cage']['id'],
            'flock_id' => $f['flock']['id'],
            'source_daily_record_id' => null,
            'observed_at' => now(),
            'observation' => 'Temuan lama yang sudah ditutup',
            'attention' => 'routine',
            'assignee_id' => $f['operator']->id,
            'status' => 'closed',
            'version' => 3,
            'recorded_by' => $f['owner']->id,
            'accepted_at' => now(),
            'updated_at' => now(),
        ]);

        return (object) ['id' => $id, 'version' => 3, 'status' => 'closed'];
    }

    /**
     * An action payload for an incident.
     *
     * @return array<string, mixed>
     */
    public static function action(object $incident): array
    {
        return [
            'id' => (string) str()->uuid(),
            'base_version' => (int) $incident->version,
            'notes' => 'Menutup temuan',
            'status' => 'closed',
        ];
    }

    /**
     * Persist an accepted photo for the given farm scenario.
     *
     * @param  array<string, mixed>  $f
     */
    public static function acceptedPhoto(array $f): object
    {
        $id = (string) str()->uuid();
        $parentId = (string) str()->uuid();
        $storageKey = 'attachments/'.$id.'.jpg';

        // A real accepted daily record so the parent scope check passes.
        DB::table('daily_records')->insert([
            'id' => $parentId,
            'farm_id' => $f['farm_id'],
            'flock_id' => $f['flock']['id'],
            'business_date' => now()->format('Y-m-d'),
            'feed_type_id' => $f['feed']['id'],
            'feed_kg' => '12.50',
            'eggs_count' => 85,
            'mortality_count' => 0,
            'condition' => 'normal',
            'version' => 1,
            'recorded_by' => $f['owner']->id,
            'accepted_at' => now(),
            'updated_at' => now(),
        ]);

        Storage::disk('private')
            ->put($storageKey, 'photo-bytes');

        DB::table('attachments')->insert([
            'id' => $id,
            'farm_id' => $f['farm_id'],
            'parent_type' => 'daily',
            'parent_id' => $parentId,
            'storage_key' => $storageKey,
            'source_sha256' => hash('sha256', 'photo-bytes'),
            'media_type' => 'image/jpeg',
            'byte_size' => 11,
            'uploaded_by' => $f['owner']->id,
            'accepted_at' => now(),
        ]);

        return (object) ['id' => $id, 'storage_key' => $storageKey];
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
