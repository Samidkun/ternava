<?php

namespace Tests\Feature;

use App\Attachments\PhotoSanitizer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\Support\Scenario;
use Tests\TestCase;

class AttachmentTest extends TestCase
{
    use RefreshDatabase;

    /** @var array<string, mixed> */
    private array $f;

    protected function setUp(): void
    {
        parent::setUp();
        $this->f = Scenario::persist(Scenario::layerFarm());
        Storage::fake('private');
    }

    /**
     * A real, decodable 1x1 JPEG.
     */
    private function realJpeg(): string
    {
        $img = imagecreatetruecolor(2, 2);
        imagefilledrectangle($img, 0, 0, 2, 2, imagecolorallocate($img, 10, 120, 60));
        ob_start();
        imagejpeg($img);
        $bytes = (string) ob_get_clean();
        imagedestroy($img);

        return $bytes;
    }

    /**
     * A real, decodable 2x2 PNG.
     */
    private function realPng(): string
    {
        $img = imagecreatetruecolor(2, 2);
        ob_start();
        imagepng($img);
        $bytes = (string) ob_get_clean();
        imagedestroy($img);

        return $bytes;
    }

    private function upload(string $parentType, string $parentId, string $bytes, string $name = 'foto.jpg')
    {
        $file = UploadedFile::fake()->createWithContent($name, $bytes);

        return $this->actingAs($this->f['owner'])
            ->withHeader('Idempotency-Key', (string) str()->uuid())
            ->post('/api/v1/attachments', [
                'id' => (string) str()->uuid(),
                'parent_type' => $parentType,
                'parent_id' => $parentId,
                'sha256' => hash('sha256', $bytes),
                'file' => $file,
            ]);
    }

    private function acceptedDaily(): object
    {
        $id = (string) str()->uuid();
        DB::table('daily_records')->insert([
            'id' => $id,
            'farm_id' => $this->f['farm_id'],
            'flock_id' => $this->f['flock']['id'],
            'business_date' => now()->format('Y-m-d'),
            'feed_type_id' => $this->f['feed']['id'],
            'feed_kg' => '12.50',
            'eggs_count' => 85,
            'mortality_count' => 0,
            'condition' => 'normal',
            'version' => 1,
            'recorded_by' => $this->f['operator']->id,
            'accepted_at' => now(),
            'updated_at' => now(),
        ]);

        return (object) ['id' => $id];
    }

    public function test_valid_jpeg_upload_is_accepted(): void
    {
        $daily = $this->acceptedDaily();
        $this->upload('daily', $daily->id, $this->realJpeg())->assertStatus(201);

        $row = DB::table('attachments')->first();
        $this->assertSame('image/jpeg', $row->media_type);
        Storage::disk('private')->assertExists($row->storage_key);
    }

    public function test_valid_png_upload_is_accepted(): void
    {
        $daily = $this->acceptedDaily();
        $this->upload('daily', $daily->id, $this->realPng(), 'foto.png')->assertStatus(201);

        $row = DB::table('attachments')->first();
        $this->assertSame('image/png', $row->media_type);
    }

    public function test_fake_mime_is_rejected(): void
    {
        $daily = $this->acceptedDaily();
        $this->upload('daily', $daily->id, 'not an image at all', 'foto.jpg')
            ->assertStatus(422);

        $this->assertDatabaseCount('attachments', 0);
    }

    public function test_corrupt_image_is_rejected(): void
    {
        $daily = $this->acceptedDaily();
        // JPEG magic bytes but truncated body -> fails a real decode.
        $this->upload('daily', $daily->id, "\xFF\xD8\xFF\xE0garbage", 'foto.jpg')
            ->assertStatus(422);

        $this->assertDatabaseCount('attachments', 0);
    }

    public function test_oversize_upload_is_rejected(): void
    {
        $daily = $this->acceptedDaily();
        $big = $this->realJpeg().str_repeat('x', 3 * 1024 * 1024);
        $this->upload('daily', $daily->id, $big)->assertStatus(422);

        $this->assertDatabaseCount('attachments', 0);
    }

    public function test_max_three_photos_per_parent(): void
    {
        $daily = $this->acceptedDaily();
        for ($i = 0; $i < 3; $i++) {
            $this->upload('daily', $daily->id, $this->realJpeg())->assertStatus(201);
        }

        $this->upload('daily', $daily->id, $this->realJpeg())->assertStatus(422);
        $this->assertDatabaseCount('attachments', 3);
    }

    public function test_hash_is_over_original_bytes(): void
    {
        $daily = $this->acceptedDaily();
        $original = $this->realJpeg();
        $this->upload('daily', $daily->id, $original)->assertStatus(201);

        $row = DB::table('attachments')->first();
        $this->assertSame(hash('sha256', $original), $row->source_sha256);
    }

    public function test_cross_farm_photo_download_is_private(): void
    {
        $photo = Scenario::acceptedPhoto($this->f);
        $this->actingAs($this->f['other'])
            ->get('/api/v1/attachments/'.$photo->id.'/download')
            ->assertNotFound();
    }

    public function test_owner_can_download_own_photo(): void
    {
        $photo = Scenario::acceptedPhoto($this->f);
        $this->actingAs($this->f['owner'])
            ->get('/api/v1/attachments/'.$photo->id.'/download')
            ->assertOk();
    }

    public function test_upload_to_foreign_parent_is_rejected(): void
    {
        $this->upload('daily', (string) str()->uuid(), $this->realJpeg())
            ->assertStatus(422);
    }

    public function test_upload_to_incident_parent_is_allowed(): void
    {
        $incident = Scenario::closedIncident($this->f);
        // Use an open incident so the parent is accepted and accessible.
        DB::table('incidents')->where('id', $incident->id)->update(['status' => 'open']);

        $this->upload('incident', $incident->id, $this->realJpeg())->assertStatus(201);
    }

    public function test_list_attachments_is_scoped_to_parent(): void
    {
        $daily = $this->acceptedDaily();
        $this->upload('daily', $daily->id, $this->realJpeg())->assertStatus(201);

        $res = $this->actingAs($this->f['owner'])
            ->getJson('/api/v1/attachments?parent_type=daily&parent_id='.$daily->id)
            ->assertOk();

        $res->assertJsonCount(1, 'data');
    }

    public function test_staging_file_is_cleaned_after_failure(): void
    {
        $daily = $this->acceptedDaily();
        // A second upload beyond the limit fails inside the transaction.
        for ($i = 0; $i < 3; $i++) {
            $this->upload('daily', $daily->id, $this->realJpeg())->assertStatus(201);
        }

        $before = count(Storage::disk('private')->allFiles());
        $this->upload('daily', $daily->id, $this->realJpeg())->assertStatus(422);
        $after = count(Storage::disk('private')->allFiles());

        $this->assertSame($before, $after, 'Staging file must be cleaned up after a failed upload.');
    }

    public function test_sanitizer_strips_exif_but_keeps_decodable_image(): void
    {
        $sanitizer = app(PhotoSanitizer::class);
        $tmp = tempnam(sys_get_temp_dir(), 'ternava');
        file_put_contents($tmp, $this->realJpeg());
        $file = new UploadedFile($tmp, 'foto.jpg', 'image/jpeg', null, true);

        $clean = $sanitizer->sanitize($file);
        $img = imagecreatefromstring($clean);
        $this->assertNotFalse($img);
        imagedestroy($img);
    }
}
