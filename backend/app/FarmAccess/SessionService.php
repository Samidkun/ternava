<?php

declare(strict_types=1);

namespace App\FarmAccess;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpKernel\Exception\UnauthorizedHttpException;

class SessionService
{
    /**
     * @param  array{username: string, password: string}  $input
     * @return array<string, mixed>
     */
    public function login(array $input): array
    {
        $user = User::whereRaw('lower(username) = ?', [strtolower(trim($input['username']))])
            ->where('active', true)
            ->first();

        if (! $user || ! Hash::check($input['password'], $user->password_hash)) {
            throw new UnauthorizedHttpException('Bearer', 'Kredensial tidak valid.');
        }

        // Fetch active membership and farm
        $membership = DB::table('memberships')
            ->join('farms', 'memberships.farm_id', '=', 'farms.id')
            ->where('memberships.user_id', $user->id)
            ->where('memberships.active', true)
            ->select(
                'memberships.id as membership_id',
                'memberships.farm_id',
                'memberships.role',
                'farms.name as farm_name',
                'farms.timezone',
                'farms.currency'
            )
            ->first();

        $farmId = $membership ? $membership->farm_id : '';
        $role = $membership ? $membership->role : 'operator';
        $farmName = $membership ? $membership->farm_name : '';
        $timezone = $membership ? $membership->timezone : 'Asia/Jakarta';
        $currency = $membership ? $membership->currency : 'IDR';

        // Assigned cages
        $cageIds = [];
        if ($membership) {
            $cageIds = DB::table('cage_assignments')
                ->where('membership_id', $membership->membership_id)
                ->pluck('cage_id')
                ->toArray();
        }

        $now = now();
        $tokenExpiresAt = $now->copy()->addDays(7);
        $offlineValidUntil = $now->copy()->addHours(24);

        $token = $user->createToken('ternava-mobile', ['*'], $tokenExpiresAt)->plainTextToken;

        return [
            'token' => $token,
            'token_expires_at' => $tokenExpiresAt->toISOString(),
            'server_time' => $now->toISOString(),
            'offline_valid_until' => $offlineValidUntil->toISOString(),
            'must_change_password' => (bool) $user->must_change_password,
            'actor' => [
                'id' => $user->id,
                'username' => $user->username,
                'display_name' => $user->display_name,
                'role' => $role,
                'must_change_password' => (bool) $user->must_change_password,
                'farm_id' => $farmId,
                'farm_name' => $farmName,
                'timezone' => $timezone,
                'currency' => $currency,
                'cage_ids' => $cageIds,
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function session(User $user): array
    {
        $membership = DB::table('memberships')
            ->join('farms', 'memberships.farm_id', '=', 'farms.id')
            ->where('memberships.user_id', $user->id)
            ->where('memberships.active', true)
            ->select(
                'memberships.id as membership_id',
                'memberships.farm_id',
                'memberships.role',
                'farms.name as farm_name',
                'farms.timezone',
                'farms.currency'
            )
            ->first();

        $farmId = $membership ? $membership->farm_id : '';
        $role = $membership ? $membership->role : 'operator';
        $farmName = $membership ? $membership->farm_name : '';
        $timezone = $membership ? $membership->timezone : 'Asia/Jakarta';
        $currency = $membership ? $membership->currency : 'IDR';

        $cageIds = [];
        if ($membership) {
            $cageIds = DB::table('cage_assignments')
                ->where('membership_id', $membership->membership_id)
                ->pluck('cage_id')
                ->toArray();
        }

        $now = now();

        return [
            'server_time' => $now->toISOString(),
            'offline_valid_until' => $now->copy()->addHours(24)->toISOString(),
            'token_expires_at' => $now->copy()->addDays(7)->toISOString(),
            'actor' => [
                'id' => $user->id,
                'username' => $user->username,
                'display_name' => $user->display_name,
                'role' => $role,
                'must_change_password' => (bool) $user->must_change_password,
                'farm_id' => $farmId,
                'farm_name' => $farmName,
                'timezone' => $timezone,
                'currency' => $currency,
                'cage_ids' => $cageIds,
            ],
        ];
    }

    public function changePassword(User $user, string $currentPassword, string $newPassword): void
    {
        if (! Hash::check($currentPassword, $user->password_hash)) {
            throw ValidationException::withMessages([
                'current_password' => ['Kata sandi saat ini tidak cocok.'],
            ]);
        }

        if (strlen($newPassword) < 8) {
            throw ValidationException::withMessages([
                'new_password' => ['Kata sandi baru minimal 8 karakter.'],
            ]);
        }

        $user->password_hash = Hash::make($newPassword);
        $user->must_change_password = false;
        $user->save();

        // Revoke all existing tokens except the current one or all tokens
        $user->tokens()->delete();
    }

    public function logout(User $user): void
    {
        /** @var PersonalAccessToken|null $token */
        $token = $user->currentAccessToken();
        $token?->delete();
    }
}
