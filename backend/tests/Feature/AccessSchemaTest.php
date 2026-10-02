<?php

namespace Tests\Feature;

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\Scenario;
use Tests\TestCase;

class AccessSchemaTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_one_active_owner_per_farm(): void
    {
        $f = Scenario::layerFarm();
        $farmId = (string) str()->uuid();
        $user1 = (string) str()->uuid();
        $user2 = (string) str()->uuid();

        // Setup base farm and users
        DB::table('farms')->insert([
            'id' => $farmId,
            'name' => 'Farm Test',
            'location' => 'Malang',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('users')->insert([
            [
                'id' => $user1,
                'username' => 'owner1',
                'display_name' => 'Owner 1',
                'password_hash' => 'hash',
                'must_change_password' => false,
                'active' => true,
            ],
            [
                'id' => $user2,
                'username' => 'owner2',
                'display_name' => 'Owner 2',
                'password_hash' => 'hash',
                'must_change_password' => false,
                'active' => true,
            ],
        ]);

        // Insert first active owner
        DB::table('memberships')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $farmId,
            'user_id' => $user1,
            'role' => 'owner',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        // Second active owner must fail with partial unique index violation
        $this->expectException(QueryException::class);

        DB::table('memberships')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $farmId,
            'user_id' => $user2,
            'role' => 'owner',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);
    }

    public function test_username_is_case_folded_unique(): void
    {
        DB::table('users')->insert([
            'id' => (string) str()->uuid(),
            'username' => 'peternak_hebat',
            'display_name' => 'Peternak',
            'password_hash' => 'hash',
            'must_change_password' => false,
            'active' => true,
        ]);

        $this->expectException(QueryException::class);

        DB::table('users')->insert([
            'id' => (string) str()->uuid(),
            'username' => 'PETERNAK_HEBAT',
            'display_name' => 'Peternak Duplikat',
            'password_hash' => 'hash',
            'must_change_password' => false,
            'active' => true,
        ]);
    }

    public function test_idempotency_receipt_unique_constraint(): void
    {
        $farmId = (string) str()->uuid();
        $userId = (string) str()->uuid();
        $opId = (string) str()->uuid();

        DB::table('farms')->insert([
            'id' => $farmId,
            'name' => 'Receipt Farm',
            'location' => 'Batu',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('users')->insert([
            'id' => $userId,
            'username' => 'receipt_user',
            'display_name' => 'Receipt User',
            'password_hash' => 'hash',
            'must_change_password' => false,
            'active' => true,
        ]);

        DB::table('idempotency_receipts')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $farmId,
            'actor_id' => $userId,
            'operation_id' => $opId,
            'request_hash' => hash('sha256', 'payload1'),
            'method' => 'POST',
            'path' => '/api/v1/daily-records',
            'ack' => json_encode(['status' => 'accepted']),
            'accepted_at' => now(),
        ]);

        $this->expectException(QueryException::class);

        DB::table('idempotency_receipts')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $farmId,
            'actor_id' => $userId,
            'operation_id' => $opId,
            'request_hash' => hash('sha256', 'payload2'),
            'method' => 'POST',
            'path' => '/api/v1/daily-records',
            'ack' => json_encode(['status' => 'accepted']),
            'accepted_at' => now(),
        ]);
    }
}
