<?php

declare(strict_types=1);

namespace App\Support;

use Illuminate\Validation\ValidationException;

class WireValidator
{
    /**
     * Enforce strict two-decimal string format for weight (kg).
     *
     * @throws ValidationException
     */
    public static function requireKg(mixed $value, string $field = 'feed_kg'): string
    {
        if (! is_string($value) || ! preg_match('/^(0|[1-9][0-9]{0,11})\.[0-9]{2}$/D', $value)) {
            throw ValidationException::withMessages([
                $field => ['Gunakan kg dengan dua angka desimal.'],
            ]);
        }

        return $value;
    }
}
