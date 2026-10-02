<?php

declare(strict_types=1);

namespace App\Attachments;

use Illuminate\Http\UploadedFile;
use Illuminate\Validation\ValidationException;

class PhotoSanitizer
{
    public const MAX_BYTES = 2 * 1024 * 1024;

    /**
     * Validate a JPEG/PNG by actually decoding it, then re-encode to strip
     * EXIF and any embedded metadata. Returns the sanitized bytes.
     */
    public function sanitize(UploadedFile $file): string
    {
        if ($file->getSize() > self::MAX_BYTES) {
            throw ValidationException::withMessages([
                'file' => ['Foto maksimal 2 MiB.'],
            ]);
        }

        $path = $file->getRealPath();
        $bytes = $path !== false ? (string) file_get_contents($path) : '';

        $image = @imagecreatefromstring($bytes);
        if ($image === false) {
            throw ValidationException::withMessages([
                'file' => ['Gunakan JPEG atau PNG yang dapat dibuka.'],
            ]);
        }

        // Detect the true media type from the decoded resource.
        $mediaType = $this->detectMediaType($bytes, $image);

        ob_start();
        if ($mediaType === 'image/png') {
            imagepng($image);
        } else {
            imagejpeg($image, null, 88);
        }
        $clean = (string) ob_get_clean();
        imagedestroy($image);

        // Re-encoding must not blow past the size limit.
        if (strlen($clean) > self::MAX_BYTES) {
            throw ValidationException::withMessages([
                'file' => ['Foto maksimal 2 MiB.'],
            ]);
        }

        return $clean;
    }

    /**
     * @param  \GdImage  $image
     */
    private function detectMediaType(string $bytes, $image): string
    {
        // PNG signature.
        if (str_starts_with($bytes, "\x89PNG\r\n\x1a\n")) {
            return 'image/png';
        }

        // JPEG signature.
        if (str_starts_with($bytes, "\xFF\xD8\xFF")) {
            return 'image/jpeg';
        }

        throw ValidationException::withMessages([
            'file' => ['Gunakan JPEG atau PNG yang dapat dibuka.'],
        ]);
    }
}
