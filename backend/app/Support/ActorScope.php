<?php

declare(strict_types=1);

namespace App\Support;

final readonly class ActorScope
{
    /**
     * @param  string[]  $cageIds
     */
    public function __construct(
        public string $actorId,
        public string $farmId,
        public string $role,
        public array $cageIds = []
    ) {}

    public function isOwner(): bool
    {
        return $this->role === 'owner';
    }

    public function isAdmin(): bool
    {
        return $this->role === 'admin';
    }

    public function isOperator(): bool
    {
        return $this->role === 'operator';
    }

    public function canAccessCage(string $cageId): bool
    {
        if ($this->isOwner() || $this->isAdmin()) {
            return true;
        }

        return in_array($cageId, $this->cageIds, true);
    }
}
