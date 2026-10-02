<?php

declare(strict_types=1);

namespace App\Attachments;

use App\Contracts\Dto\Ack;
use App\Support\ActorScope;
use App\Support\ChangeWriter;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

class AttachmentService
{
    public const MAX_PER_PARENT = 3;

    public const DISK = 'private';

    public function __construct(
        protected PhotoSanitizer $sanitizer
    ) {}

    /**
     * Upload a private photo. The hash is computed over the ORIGINAL bytes
     * (before EXIF stripping) so the client can verify integrity.
     */
    public function upload(ActorScope $actor, array $input, string $key, UploadedFile $file): Ack
    {
        $parentType = (string) $input['parent_type'];
        $parentId = (string) $input['parent_id'];

        // Authorize + validate the parent before touching storage.
        $this->assertParentAccessible($actor, $parentType, $parentId);

        $originalBytes = (string) file_get_contents((string) $file->getRealPath());
        $originalHash = hash('sha256', $originalBytes);

        // Reject when the client-declared hash does not match the real bytes.
        if (isset($input['sha256']) && ! hash_equals((string) $input['sha256'], $originalHash)) {
            throw ValidationException::withMessages([
                'sha256' => ['Hash tidak cocok dengan byte yang diunggah.'],
            ]);
        }

        // Decode + re-encode to strip EXIF; throws 422 for fake/corrupt/oversize.
        $clean = $this->sanitizer->sanitize($file);
        $mediaType = $this->mediaTypeOf($originalBytes);

        return DB::transaction(function () use ($actor, $input, $parentType, $parentId, $clean, $originalHash, $mediaType) {
            // Enforce the per-parent cap inside the transaction. Postgres
            // disallows FOR UPDATE with an aggregate, so lock rows and count.
            $existing = DB::table('attachments')
                ->where('farm_id', $actor->farmId)
                ->where('parent_type', $parentType)
                ->where('parent_id', $parentId)
                ->lockForUpdate()
                ->get()
                ->count();

            if ($existing >= self::MAX_PER_PARENT) {
                throw ValidationException::withMessages([
                    'file' => ['Maksimal 3 foto per catatan.'],
                ]);
            }

            $id = (string) ($input['id'] ?? Str::uuid());
            $storageKey = 'attachments/'.$id.($mediaType === 'image/png' ? '.png' : '.jpg');

            Storage::disk(self::DISK)->put($storageKey, $clean);

            try {
                DB::table('attachments')->insert([
                    'id' => $id,
                    'farm_id' => $actor->farmId,
                    'parent_type' => $parentType,
                    'parent_id' => $parentId,
                    'storage_key' => $storageKey,
                    'source_sha256' => $originalHash,
                    'media_type' => $mediaType,
                    'byte_size' => strlen($clean),
                    'uploaded_by' => $actor->actorId,
                    'accepted_at' => now(),
                ]);
            } catch (\Throwable $e) {
                // Roll back the orphaned file so no half-written blob remains.
                Storage::disk(self::DISK)->delete($storageKey);
                throw $e;
            }

            ChangeWriter::append($actor, 'attachment', $id, 'upsert', [
                'id' => $id,
                'parent_type' => $parentType,
                'parent_id' => $parentId,
                'media_type' => $mediaType,
                'byte_size' => strlen($clean),
            ]);

            return Ack::fromArray([
                'status' => 'accepted',
                'id' => $id,
                'media_type' => $mediaType,
                'byte_size' => strlen($clean),
            ]);
        }, 3);
    }

    /**
     * @param  array<string, mixed>  $query
     * @return array<int, array<string, mixed>>
     */
    public function list(ActorScope $actor, array $query = []): array
    {
        $parentType = (string) ($query['parent_type'] ?? '');
        $parentId = (string) ($query['parent_id'] ?? '');

        if ($parentType !== '' && $parentId !== '') {
            $this->assertParentAccessible($actor, $parentType, $parentId);
        }

        $q = DB::table('attachments')->where('farm_id', $actor->farmId);
        if ($parentType !== '') {
            $q->where('parent_type', $parentType);
        }
        if ($parentId !== '') {
            $q->where('parent_id', $parentId);
        }

        return $q->orderBy('accepted_at')
            ->get()
            ->map(fn ($r) => [
                'id' => $r->id,
                'parent_type' => $r->parent_type,
                'parent_id' => $r->parent_id,
                'media_type' => $r->media_type,
                'byte_size' => (int) $r->byte_size,
                'accepted_at' => $r->accepted_at,
            ])
            ->toArray();
    }

    /**
     * Stream a private photo. Never exposes the storage key, and always
     * re-checks farm scope so cross-farm downloads are impossible.
     */
    public function download(ActorScope $actor, string $id): StreamedResponse
    {
        $row = DB::table('attachments')
            ->where('id', $id)
            ->where('farm_id', $actor->farmId)
            ->first();

        if (! $row) {
            throw new NotFoundHttpException('Lampiran tidak ditemukan.');
        }

        // The parent must still be accessible to the caller.
        $this->assertParentAccessible($actor, (string) $row->parent_type, (string) $row->parent_id);

        $disk = Storage::disk(self::DISK);
        if (! $disk->exists((string) $row->storage_key)) {
            throw new NotFoundHttpException('Berkas lampiran tidak ditemukan.');
        }

        $stream = $disk->readStream((string) $row->storage_key);
        if ($stream === null) {
            throw new NotFoundHttpException('Berkas lampiran tidak ditemukan.');
        }

        return new StreamedResponse(function () use ($stream): void {
            fpassthru($stream);
            if (is_resource($stream)) {
                fclose($stream);
            }
        }, 200, [
            'Content-Type' => (string) $row->media_type,
            'Cache-Control' => 'private, no-store',
        ]);
    }

    private function assertParentAccessible(ActorScope $actor, string $parentType, string $parentId): void
    {
        $exists = match ($parentType) {
            'daily' => DB::table('daily_records')
                ->where('id', $parentId)
                ->where('farm_id', $actor->farmId)
                ->exists(),
            'incident' => DB::table('incidents')
                ->where('id', $parentId)
                ->where('farm_id', $actor->farmId)
                ->exists(),
            default => false,
        };

        if (! $exists) {
            throw new UnprocessableEntityHttpException('Induk lampiran tidak ditemukan di farm ini.');
        }
    }

    private function mediaTypeOf(string $bytes): string
    {
        if (str_starts_with($bytes, "\x89PNG\r\n\x1a\n")) {
            return 'image/png';
        }

        if (str_starts_with($bytes, "\xFF\xD8\xFF")) {
            return 'image/jpeg';
        }

        throw new AccessDeniedHttpException('Tipe gambar tidak dikenali.');
    }
}
