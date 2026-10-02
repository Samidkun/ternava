<?php

declare(strict_types=1);

namespace App\Incidents;

use App\Support\ActorScope;

final class IncidentPolicy
{
    /**
     * Owners/admins manage assignments; operators may only act on incidents
     * assigned to them.
     */
    public function canAssign(ActorScope $actor): bool
    {
        return $actor->isOwner() || $actor->isAdmin();
    }

    /**
     * @param  array<string, mixed>  $incident
     */
    public function canAct(ActorScope $actor, array $incident): bool
    {
        if ($this->canAssign($actor)) {
            return true;
        }

        return (string) ($incident['assignee_id'] ?? '') === $actor->actorId;
    }
}
