<?php

declare(strict_types=1);

namespace App\Sync;

use Symfony\Component\HttpKernel\Exception\ConflictHttpException;

class CursorCodec
{
    /**
     * @param  array<string, mixed>  $claims
     */
    public static function encode(array $claims): string
    {
        $payload = json_encode($claims, JSON_THROW_ON_ERROR);
        $key = (string) config('app.key');
        $sig = hash_hmac('sha256', $payload, $key);

        return rtrim(strtr(base64_encode($payload), '+/', '-_'), '=').'.'.$sig;
    }

    /**
     * @return array<string, mixed>
     *
     * @throws ConflictHttpException
     */
    public static function decode(string $cursor): array
    {
        $parts = explode('.', $cursor);
        if (count($parts) !== 2) {
            throw new ConflictHttpException('CURSOR_RESET_REQUIRED: Cursor tidak valid.');
        }

        [$rawPayload, $sig] = $parts;
        $decoded = base64_decode(strtr($rawPayload, '-_', '+/'));
        if (! $decoded) {
            throw new ConflictHttpException('CURSOR_RESET_REQUIRED: Cursor corrupt.');
        }

        $key = (string) config('app.key');
        $expectedSig = hash_hmac('sha256', $decoded, $key);
        if (! hash_equals($expectedSig, $sig)) {
            throw new ConflictHttpException('CURSOR_RESET_REQUIRED: Signature cursor tidak valid.');
        }

        /** @var array<string, mixed> $claims */
        $claims = json_decode($decoded, true, 512, JSON_THROW_ON_ERROR);

        if (isset($claims['expires_at']) && (int) $claims['expires_at'] < time()) {
            throw new ConflictHttpException('CURSOR_RESET_REQUIRED: Masa berlaku cursor sinkronisasi telah habis.');
        }

        return $claims;
    }
}
