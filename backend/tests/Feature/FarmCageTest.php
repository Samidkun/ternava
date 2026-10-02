<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class FarmCageTest extends TestCase
{
    use RefreshDatabase;

    private string $farmId;

    private User $owner;

    private User $operator;

    private string $assignedCageId;

    private string $hiddenCageId;

    protected function setUp(): void
    {
        parent::setUp();

        $this->farmId = (string) Str::uuid();

        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Sukses Makmur',
            'location' => 'Malang',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->owner = new User([
            'id' => (string) Str::uuid(),
            'username' => 'owner_joko',
            'display_name' => 'Pak Joko',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->owner->save();

        $this->operator = new User([
            'id' => (string) Str::uuid(),
            'username' => 'operator_budi',
            'display_name' => 'Budi',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->operator->save();

        $ownerMembershipId = (string) Str::uuid();
        DB::table('memberships')->insert([
            'id' => $ownerMembershipId,
            'farm_id' => $this->farmId,
            'user_id' => $this->owner->id,
            'role' => 'owner',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        $operatorMembershipId = (string) Str::uuid();
        DB::table('memberships')->insert([
            'id' => $operatorMembershipId,
            'farm_id' => $this->farmId,
            'user_id' => $this->operator->id,
            'role' => 'operator',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        $this->assignedCageId = (string) Str::uuid();
        DB::table('cages')->insert([
            'id' => $this->assignedCageId,
            'farm_id' => $this->farmId,
            'code' => 'K-01',
            'name' => 'Kandang Satu',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->hiddenCageId = (string) Str::uuid();
        DB::table('cages')->insert([
            'id' => $this->hiddenCageId,
            'farm_id' => $this->farmId,
            'code' => 'K-02',
            'name' => 'Kandang Dua (Hidden for operator)',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        // Assign operator ONLY to cage 1
        DB::table('cage_assignments')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'membership_id' => $operatorMembershipId,
            'cage_id' => $this->assignedCageId,
        ]);
    }

    public function test_get_farm_profile(): void
    {
        $res = $this->actingAs($this->owner)->getJson('/api/v1/farm');
        $res->assertOk()
            ->assertJsonPath('data.name', 'Farm Sukses Makmur')
            ->assertJsonPath('data.timezone', 'Asia/Jakarta');
    }

    public function test_operator_does_not_see_other_cage(): void
    {
        // Operator should only see assigned cage (K-01)
        $res = $this->actingAs($this->operator)->getJson('/api/v1/cages');
        $res->assertOk();

        $cages = $res->json('data');
        $ids = array_column($cages, 'id');
        $this->assertContains($this->assignedCageId, $ids);
        $this->assertNotContains($this->hiddenCageId, $ids);

        // Accessing unassigned cage directly returns 404
        $detailRes = $this->actingAs($this->operator)->getJson('/api/v1/cages/'.$this->hiddenCageId);
        $detailRes->assertNotFound();
    }

    public function test_owner_can_create_cage_with_unique_code(): void
    {
        $key = (string) Str::uuid();
        $res = $this->actingAs($this->owner)
            ->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/cages', [
                'code' => 'K-03',
                'name' => 'Kandang Tiga',
                'description' => 'Kandang baru',
            ]);

        $res->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        $this->assertDatabaseHas('cages', [
            'farm_id' => $this->farmId,
            'code' => 'K-03',
        ]);
    }

    public function test_create_cage_duplicate_code_fails(): void
    {
        $key = (string) Str::uuid();
        // Case-folded duplicate ('k-01' vs 'K-01')
        $res = $this->actingAs($this->owner)
            ->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/cages', [
                'code' => 'k-01',
                'name' => 'Kandang Duplikat',
            ]);

        $res->assertStatus(409);
    }
}
