<?php

declare(strict_types=1);

namespace App\Support;

final class CanonicalJson
{
    /**
     * Sorts object keys recursively while preserving arrays/lists.
     */
    public static function canonicalize(mixed $v): mixed
    {
        if (! is_array($v)) {
            return $v;
        }

        if (! array_is_list($v)) {
            ksort($v, SORT_STRING);
        }

        return array_map([self::class, 'canonicalize'], $v);
    }

    /**
     * @param  array<string, mixed>  $value
     */
    public static function encode(array $value): string
    {
        return json_encode(
            self::canonicalize($value),
            JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
        );
    }

    /**
     * @param  array<string, mixed>  $payload
     */
    public static function hash(string $method, string $path, array $payload): string
    {
        return hash('sha256', strtoupper($method)."\n".$path."\n".self::encode($payload));
    }
}
