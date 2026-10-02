<?php

declare(strict_types=1);

namespace App\FarmAccess;

use App\Contracts\Dto\Ack;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use App\Support\MutationExecutor;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class FarmService
{
    /**
     * @return array<string, mixed>
     */
    public function get(ActorScope $actor): array
    {
        $farm = DB::table('farms')->where('id', $actor->farmId)->first();
        if (! $farm) {
            throw new NotFoundHttpException('Peternakan tidak ditemukan.');
        }

        return (array) $farm;
    }

    /**
     * @param  array<string, mixed>  $input
     */
    public function update(ActorScope $actor, array $input, string $key): Ack
    {
        return MutationExecutor::run(
            $actor,
            $key,
            'PATCH',
            '/api/v1/farm',
            $input,
            function () use ($actor) {
                if (! $actor->isOwner() && ! $actor->isAdmin()) {
                    throw new AccessDeniedHttpException('Hanya pengelola yang dapat mengubah profil peternakan.');
                }
            },
            function () use ($actor, $input) {
                $farm = DB::table('farms')->where('id', $actor->farmId)->first();
                if (! $farm) {
                    throw new NotFoundHttpException('Peternakan tidak ditemukan.');
                }

                $newVersion = (int) $farm->version + 1;
                $updateData = [
                    'name' => $input['name'] ?? $farm->name,
                    'location' => $input['location'] ?? $farm->location,
                    'timezone' => $input['timezone'] ?? $farm->timezone,
                    'version' => $newVersion,
                    'updated_at' => now(),
                ];

                DB::table('farms')->where('id', $actor->farmId)->update($updateData);

                ChangeWriter::append(
                    $actor,
                    'farm',
                    $actor->farmId,
                    'upsert',
                    $updateData
                );

                return Ack::fromArray([
                    'status' => 'accepted',
                    'version' => $newVersion,
                ]);
            }
        );
    }
}
