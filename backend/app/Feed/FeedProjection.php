<?php

declare(strict_types=1);

namespace App\Feed;

use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;

class FeedProjection
{
    /**
     * Atomically update feed balance and enforce non-negative stock constraint.
     *
     * @throws HttpException
     */
    public static function apply(
        string $feedTypeId,
        string $signedKg,
        string $sourceKind,
        string $sourceId,
        int $version
    ): void {
        $affected = DB::update(
            'UPDATE feed_balances SET quantity_kg = quantity_kg + CAST(? AS numeric), updated_at = ? WHERE feed_type_id = ? AND quantity_kg + CAST(? AS numeric) BETWEEN 0 AND 999999999999.99',
            [$signedKg, now(), $feedTypeId, $signedKg]
        );

        if ($affected !== 1) {
            throw new HttpException(422, 'Saldo pakan tidak mencukupi untuk pemotongan ini.', null, [], 422);
        }
    }
}
