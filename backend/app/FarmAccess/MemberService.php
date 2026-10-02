<?php

declare(strict_types=1);

namespace App\FarmAccess;

use App\Contracts\Dto\Ack;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use App\Support\MutationExecutor;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class MemberService
{
    /**
     * @param  array<string, mixed>  $query
     * @return array<int, array<string, mixed>>
     */
    public function list(ActorScope $actor, array $query = []): array
    {
        if ($actor->isOperator()) {
            throw new AccessDeniedHttpException('Operator tidak dapat melihat daftar anggota.');
        }

        $members = DB::table('memberships')
            ->join('users', 'memberships.user_id', '=', 'users.id')
            ->where('memberships.farm_id', $actor->farmId)
            ->select(
                'memberships.id',
                'memberships.farm_id',
                'memberships.user_id',
                'users.username',
                'users.display_name',
                'memberships.role',
                'memberships.active',
                'memberships.version'
            )
            ->get();

        $result = [];
        foreach ($members as $m) {
            $cageIds = DB::table('cage_assignments')
                ->where('membership_id', $m->id)
                ->pluck('cage_id')
                ->toArray();

            $result[] = array_merge((array) $m, ['cage_ids' => $cageIds]);
        }

        return $result;
    }

    /**
     * @return array<string, mixed>
     */
    public function get(ActorScope $actor, string $id): array
    {
        if ($actor->isOperator()) {
            throw new AccessDeniedHttpException('Operator tidak dapat melihat anggota.');
        }

        $member = DB::table('memberships')
            ->join('users', 'memberships.user_id', '=', 'users.id')
            ->where('memberships.id', $id)
            ->where('memberships.farm_id', $actor->farmId)
            ->select(
                'memberships.id',
                'memberships.farm_id',
                'memberships.user_id',
                'users.username',
                'users.display_name',
                'memberships.role',
                'memberships.active',
                'memberships.version'
            )
            ->first();

        if (! $member) {
            throw new NotFoundHttpException('Anggota tidak ditemukan.');
        }

        $cageIds = DB::table('cage_assignments')
            ->where('membership_id', $id)
            ->pluck('cage_id')
            ->toArray();

        return array_merge((array) $member, ['cage_ids' => $cageIds]);
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function create(ActorScope $actor, array $input, string $key): Ack
    {
        $requestedRole = (string) $input['role'];
        MemberPolicy::authorizeCreate($actor, $requestedRole);

        return MutationExecutor::run(
            $actor,
            $key,
            'POST',
            '/api/v1/members',
            $input,
            function () use ($actor, $requestedRole) {
                MemberPolicy::authorizeCreate($actor, $requestedRole);
            },
            function () use ($actor, $input, $requestedRole) {
                $username = trim((string) $input['username']);
                $userExists = DB::table('users')
                    ->whereRaw('lower(username) = ?', [strtolower($username)])
                    ->exists();

                if ($userExists) {
                    throw new ConflictHttpException("Nama pengguna '{$username}' sudah digunakan.");
                }

                $userId = (string) Str::uuid();
                $membershipId = (string) ($input['id'] ?? Str::uuid());

                DB::table('users')->insert([
                    'id' => $userId,
                    'username' => $username,
                    'display_name' => trim((string) $input['display_name']),
                    'password_hash' => Hash::make((string) $input['temporary_password']),
                    'must_change_password' => true,
                    'active' => (bool) ($input['active'] ?? true),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);

                $membershipData = [
                    'id' => $membershipId,
                    'farm_id' => $actor->farmId,
                    'user_id' => $userId,
                    'role' => $requestedRole,
                    'scope_version' => 1,
                    'version' => 1,
                    'active' => (bool) ($input['active'] ?? true),
                ];
                DB::table('memberships')->insert($membershipData);

                // Cage assignments
                if (! empty($input['cage_ids'])) {
                    foreach ($input['cage_ids'] as $cageId) {
                        DB::table('cage_assignments')->insert([
                            'id' => (string) Str::uuid(),
                            'farm_id' => $actor->farmId,
                            'membership_id' => $membershipId,
                            'cage_id' => $cageId,
                        ]);
                    }
                }

                ChangeWriter::append(
                    $actor,
                    'member',
                    $membershipId,
                    'upsert',
                    $membershipData
                );

                return Ack::fromArray([
                    'status' => 'accepted',
                    'id' => $membershipId,
                    'version' => 1,
                ]);
            }
        );
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function update(ActorScope $actor, string $id, array $input, string $key): Ack
    {
        $member = DB::table('memberships')
            ->where('id', $id)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $member) {
            throw new NotFoundHttpException('Anggota tidak ditemukan.');
        }

        $targetRole = (string) $member->role;
        $requestedRole = isset($input['role']) ? (string) $input['role'] : $targetRole;
        MemberPolicy::authorizeUpdate($actor, $targetRole, $requestedRole);

        return MutationExecutor::run(
            $actor,
            $key,
            'PATCH',
            "/api/v1/members/{$id}",
            $input,
            function () use ($actor, $targetRole, $requestedRole) {
                MemberPolicy::authorizeUpdate($actor, $targetRole, $requestedRole);
            },
            function () use ($actor, $member, $id, $input, $requestedRole) {
                $newVersion = (int) $member->version + 1;
                $newScopeVersion = (int) $member->scope_version + 1;

                DB::table('memberships')->where('id', $id)->update([
                    'role' => $requestedRole,
                    'active' => isset($input['active']) ? (bool) $input['active'] : $member->active,
                    'version' => $newVersion,
                    'scope_version' => $newScopeVersion,
                ]);

                if (isset($input['display_name'])) {
                    DB::table('users')->where('id', $member->user_id)->update([
                        'display_name' => trim((string) $input['display_name']),
                        'updated_at' => now(),
                    ]);
                }

                // Update cage assignments if provided
                if (array_key_exists('cage_ids', $input)) {
                    DB::table('cage_assignments')->where('membership_id', $id)->delete();
                    foreach ($input['cage_ids'] as $cageId) {
                        DB::table('cage_assignments')->insert([
                            'id' => (string) Str::uuid(),
                            'farm_id' => $actor->farmId,
                            'membership_id' => $id,
                            'cage_id' => $cageId,
                        ]);
                    }
                }

                ChangeWriter::append(
                    $actor,
                    'member',
                    $id,
                    'upsert',
                    [
                        'id' => $id,
                        'role' => $requestedRole,
                        'version' => $newVersion,
                        'scope_version' => $newScopeVersion,
                    ]
                );

                return Ack::fromArray([
                    'status' => 'accepted',
                    'id' => $id,
                    'version' => $newVersion,
                ]);
            }
        );
    }
}
