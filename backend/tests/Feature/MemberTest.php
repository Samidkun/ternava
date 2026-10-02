<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Tests\TestCase;

class MemberTest extends TestCase
{
    use RefreshDatabase;

    private string $farmId;

    private User $owner;

    private User $admin;

    private User $operator;

    private string $ownerMembershipId;

    private string $operatorMembershipId;

    private string $cageId;

    protected function setUp(): void
    {
        parent::setUp();

        $this->farmId = (string) Str::uuid();

        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Member Test',
            'location' => 'Kediri',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->owner = new User([
            'id' => (string) Str::uuid(),
            'username' => 'owner_sutrisno',
            'display_name' => 'Pak Sutrisno',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->owner->save();

        $this->admin = new User([
            'id' => (string) Str::uuid(),
            'username' => 'admin_dewi',
            'display_name' => 'Bu Dewi',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->admin->save();

        $this->operator = new User([
            'id' => (string) Str::uuid(),
            'username' => 'operator_edi',
            'display_name' => 'Edi',
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);
        $this->operator->save();

        $this->ownerMembershipId = (string) Str::uuid();
        DB::table('memberships')->insert([
            'id' => $this->ownerMembershipId,
            'farm_id' => $this->farmId,
            'user_id' => $this->owner->id,
            'role' => 'owner',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        DB::table('memberships')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'user_id' => $this->admin->id,
            'role' => 'admin',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        $this->operatorMembershipId = (string) Str::uuid();
        DB::table('memberships')->insert([
            'id' => $this->operatorMembershipId,
            'farm_id' => $this->farmId,
            'user_id' => $this->operator->id,
            'role' => 'operator',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        $this->cageId = (string) Str::uuid();
        DB::table('cages')->insert([
            'id' => $this->cageId,
            'farm_id' => $this->farmId,
            'code' => 'K-MEM-01',
            'name' => 'Kandang Member 1',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);
    }

    public function test_admin_cannot_promote_operator_to_admin(): void
    {
        $key = (string) Str::uuid();
        $res = $this->actingAs($this->admin)
            ->withHeader('Idempotency-Key', $key)
            ->patchJson('/api/v1/members/'.$this->operatorMembershipId, [
                'base_version' => 1,
                'display_name' => 'Edi Operator',
                'role' => 'admin', // Admin attempting to promote to admin
                'cage_ids' => [$this->cageId],
                'active' => true,
            ]);

        $res->assertForbidden();
    }

    public function test_owner_can_create_member_with_temporary_password(): void
    {
        $key = (string) Str::uuid();
        $newUsername = 'operator_baru_123';
        $tempPassword = 'password-sementara-1234';

        $res = $this->actingAs($this->owner)
            ->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/members', [
                'username' => $newUsername,
                'display_name' => 'Operator Baru',
                'role' => 'operator',
                'cage_ids' => [$this->cageId],
                'active' => true,
                'temporary_password' => $tempPassword,
            ]);

        $res->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        // Check user created with must_change_password = true
        $createdUser = DB::table('users')->where('username', $newUsername)->first();
        $this->assertNotNull($createdUser);
        $this->assertTrue((bool) $createdUser->must_change_password);
        $this->assertTrue(Hash::check($tempPassword, $createdUser->password_hash));

        // Check cage assignment created
        $createdMembership = DB::table('memberships')
            ->where('farm_id', $this->farmId)
            ->where('user_id', $createdUser->id)
            ->first();
        $this->assertNotNull($createdMembership);

        $this->assertDatabaseHas('cage_assignments', [
            'farm_id' => $this->farmId,
            'membership_id' => $createdMembership->id,
            'cage_id' => $this->cageId,
        ]);
    }

    public function test_owner_is_protected_from_modification(): void
    {
        $key = (string) Str::uuid();
        $res = $this->actingAs($this->admin)
            ->withHeader('Idempotency-Key', $key)
            ->patchJson('/api/v1/members/'.$this->ownerMembershipId, [
                'role' => 'operator',
                'active' => false,
            ]);

        $res->assertForbidden();
    }

    public function test_operator_cannot_access_members_endpoint(): void
    {
        $res = $this->actingAs($this->operator)->getJson('/api/v1/members');
        $res->assertForbidden();
    }
}
