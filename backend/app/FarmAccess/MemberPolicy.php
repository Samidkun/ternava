<?php

declare(strict_types=1);

namespace App\FarmAccess;

use App\Support\ActorScope;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;

class MemberPolicy
{
    public static function authorizeCreate(ActorScope $actor, string $requestedRole): void
    {
        if ($actor->isOperator()) {
            throw new AccessDeniedHttpException('Operator tidak dapat mengelola anggota.');
        }

        if ($actor->isAdmin() && $requestedRole !== 'operator') {
            throw new AccessDeniedHttpException('Admin hanya dapat mendaftarkan operator.');
        }

        if ($requestedRole === 'owner') {
            throw new AccessDeniedHttpException('Peran owner tidak dapat dibuat melalui formulir anggota.');
        }
    }

    public static function authorizeUpdate(ActorScope $actor, string $targetRole, string $requestedRole): void
    {
        if ($actor->isOperator()) {
            throw new AccessDeniedHttpException('Operator tidak dapat mengelola anggota.');
        }

        if ($targetRole === 'owner') {
            throw new AccessDeniedHttpException('Akun owner dilindungi dan tidak dapat diubah.');
        }

        if ($actor->isAdmin()) {
            if ($targetRole !== 'operator' || $requestedRole !== 'operator') {
                throw new AccessDeniedHttpException('Admin hanya dapat mengelola operator.');
            }
        }

        if ($requestedRole === 'owner') {
            throw new AccessDeniedHttpException('Tidak dapat mempromosikan menjadi owner.');
        }
    }
}
