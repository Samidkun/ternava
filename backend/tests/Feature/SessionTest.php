<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Tests\TestCase;

class SessionTest extends TestCase
{
    use RefreshDatabase;

    private string $farmId;

    private string $userId;

    protected function setUp(): void
    {
        parent::setUp();

        RateLimiter::clear('login:peternak_rate|127.0.0.1');

        $this->farmId = (string) str()->uuid();
        $this->userId = (string) str()->uuid();

        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Auth Test',
            'location' => 'Malang',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);
    }

    public function test_login_first_time_requires_password_change(): void
    {
        $username = 'peternak_baru';
        $password = 'initial-pass-1234';

        DB::table('users')->insert([
            'id' => $this->userId,
            'username' => $username,
            'display_name' => 'Peternak Baru',
            'password_hash' => Hash::make($password),
            'must_change_password' => true,
            'active' => true,
        ]);

        DB::table('memberships')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $this->farmId,
            'user_id' => $this->userId,
            'role' => 'operator',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        $res = $this->postJson('/api/v1/session', [
            'username' => $username,
            'password' => $password,
        ]);

        $res->assertOk()
            ->assertJsonPath('data.must_change_password', true)
            ->assertJsonStructure([
                'data' => [
                    'token',
                    'token_expires_at',
                    'offline_valid_until',
                    'actor',
                ],
            ]);

        $token = $res->json('data.token');

        // Accessing other business endpoints before changing password must return 403 PASSWORD_CHANGE_REQUIRED
        $blocked = $this->withToken($token)->getJson('/api/v1/cages');
        $blocked->assertStatus(403)
            ->assertJsonPath('error.code', 'PASSWORD_CHANGE_REQUIRED');
    }

    public function test_change_password_clears_must_change_flag_and_allows_access(): void
    {
        $username = 'peternak_rotasi';
        $oldPass = 'old-pass-1234';
        $newPass = 'new-secure-pass-5678';

        $user = new User([
            'id' => $this->userId,
            'username' => $username,
            'display_name' => 'Peternak Rotasi',
            'password_hash' => Hash::make($oldPass),
            'must_change_password' => true,
            'active' => true,
        ]);
        $user->save();

        DB::table('memberships')->insert([
            'id' => (string) str()->uuid(),
            'farm_id' => $this->farmId,
            'user_id' => $this->userId,
            'role' => 'operator',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        $loginRes = $this->postJson('/api/v1/session', [
            'username' => $username,
            'password' => $oldPass,
        ]);
        $token = $loginRes->json('data.token');

        // Change password
        $changeRes = $this->withToken($token)->postJson('/api/v1/account/password', [
            'current_password' => $oldPass,
            'new_password' => $newPass,
        ]);
        $changeRes->assertStatus(204);

        // Check user flag in DB
        $updatedUser = DB::table('users')->where('id', $this->userId)->first();
        $this->assertFalse((bool) $updatedUser->must_change_password);
        $this->assertTrue(Hash::check($newPass, $updatedUser->password_hash));
    }

    public function test_login_with_invalid_credentials_returns_401(): void
    {
        $res = $this->postJson('/api/v1/session', [
            'username' => 'non_existent',
            'password' => 'wrong_pass',
        ]);

        $res->assertStatus(401)
            ->assertJsonPath('error.code', 'INVALID_CREDENTIALS');
    }

    public function test_login_throttling_after_5_failed_attempts(): void
    {
        $username = 'peternak_rate';

        for ($i = 0; $i < 5; $i++) {
            $res = $this->postJson('/api/v1/session', [
                'username' => $username,
                'password' => 'wrong',
            ]);
            $res->assertStatus(401);
        }

        // 6th attempt should be blocked with 429
        $throttled = $this->postJson('/api/v1/session', [
            'username' => $username,
            'password' => 'wrong',
        ]);

        $throttled->assertStatus(429)
            ->assertJsonPath('error.code', 'RATE_LIMIT_EXCEEDED')
            ->assertHeader('Retry-After');
    }
}
