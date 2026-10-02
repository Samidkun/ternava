<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class FeedTest extends TestCase
{
    use RefreshDatabase;

    private string $farmId;

    private User $owner;

    private User $operator;

    private string $feedTypeId;

    protected function setUp(): void
    {
        parent::setUp();

        $this->farmId = (string) Str::uuid();

        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Pakan Test',
            'location' => 'Jombang',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->owner = new User([
            'id' => (string) Str::uuid(),
            'username' => 'owner_slamet',
            'display_name' => 'Pak Slamet',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->owner->save();

        $this->operator = new User([
            'id' => (string) Str::uuid(),
            'username' => 'operator_sugeng',
            'display_name' => 'Sugeng',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->operator->save();

        DB::table('memberships')->insert([
            [
                'id' => (string) Str::uuid(),
                'farm_id' => $this->farmId,
                'user_id' => $this->owner->id,
                'role' => 'owner',
                'scope_version' => 1,
                'version' => 1,
                'active' => true,
            ],
            [
                'id' => (string) Str::uuid(),
                'farm_id' => $this->farmId,
                'user_id' => $this->operator->id,
                'role' => 'operator',
                'scope_version' => 1,
                'version' => 1,
                'active' => true,
            ],
        ]);

        $this->feedTypeId = (string) Str::uuid();
        DB::table('feed_types')->insert([
            'id' => $this->feedTypeId,
            'farm_id' => $this->farmId,
            'code' => 'FEED-TEST-01',
            'name' => 'Pakan Konsentrat Broiler',
            'minimum_kg' => 50.00,
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        DB::table('feed_balances')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'feed_type_id' => $this->feedTypeId,
            'quantity_kg' => '300.00',
            'updated_at' => now(),
        ]);
    }

    public function test_adjustment_cannot_make_negative_stock(): void
    {
        $key = (string) Str::uuid();

        // Stock is 300.00, attempting to adjust out 300.01 must fail with 422 INSUFFICIENT_STOCK
        $res = $this->actingAs($this->owner)
            ->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/feed-entries', [
                'feed_type_id' => $this->feedTypeId,
                'business_date' => now()->format('Y-m-d'),
                'kind' => 'adjustment',
                'quantity_kg' => '300.01',
                'direction' => 'out',
                'reason' => 'Koreksi stok rusak melebihi saldo',
            ]);

        $res->assertStatus(422)
            ->assertJsonPath('error.code', 'INSUFFICIENT_STOCK');

        // Balance remains 300.00
        $this->assertDatabaseHas('feed_balances', [
            'feed_type_id' => $this->feedTypeId,
            'quantity_kg' => '300.00',
        ]);
    }

    public function test_valid_receipt_increases_stock_balance(): void
    {
        $key = (string) Str::uuid();

        $res = $this->actingAs($this->owner)
            ->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/feed-entries', [
                'feed_type_id' => $this->feedTypeId,
                'business_date' => now()->format('Y-m-d'),
                'kind' => 'receipt',
                'quantity_kg' => '100.00',
                'direction' => 'in',
                'unit_price_idr' => '9500.00',
                'supplier' => 'PT Pakan Subur',
            ]);

        $res->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        // Balance increased to 400.00
        $this->assertDatabaseHas('feed_balances', [
            'feed_type_id' => $this->feedTypeId,
            'quantity_kg' => '400.00',
        ]);
    }

    public function test_operator_cannot_access_purchase_ledger_entries(): void
    {
        $res = $this->actingAs($this->operator)->getJson('/api/v1/feed-entries');
        $res->assertForbidden();
    }
}
