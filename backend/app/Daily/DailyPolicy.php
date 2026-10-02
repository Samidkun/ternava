<?php

declare(strict_types=1);

namespace App\Daily;

use App\Support\ActorScope;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

class DailyPolicy
{
    public static function authorizeFlockAccess(ActorScope $actor, string $flockId): object
    {
        $flock = DB::table('flocks')
            ->where('id', $flockId)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $flock) {
            throw new NotFoundHttpException('Kelompok ayam tidak ditemukan.');
        }

        if ($actor->isOperator() && ! $actor->canAccessCage((string) $flock->cage_id)) {
            throw new AccessDeniedHttpException('Operator tidak memiliki hak akses pada kandang kelompok ini.');
        }

        return $flock;
    }
}
