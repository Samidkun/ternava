<?php

/**
 * T44 — load-test fixture generator (AC-44).
 *
 * Produces a realistic-but-synthetic dataset for the k6 benchmark:
 * one farm, N cages/flocks, one feed type with a large balance, and
 * CAGES x DATES daily records (default 100 x 1000 = 100,000 rows), each with a
 * matching feed entry and sync change, plus a sync counter watermark.
 *
 * This is a GENERATOR, not a production dataset (the plan is explicit: no
 * production data). It is safe to re-run: every farm whose name starts with the
 * marker below is dropped (cascading to all child rows) before recreating, so
 * repeated runs converge on the same shape.
 *
 * Credentials: the load users' password is read from TERNAVA_LOAD_PASSWORD, or
 * generated with a CSPRNG when unset. It is NEVER hard-coded and NEVER printed;
 * it is written only to a git-ignored runtime file (backend/storage/app/private)
 * that the k6 script reads. No secret enters the repository.
 *
 * Usage:
 *   php ops/load/seed.php                 # full 100k dataset
 *   LOAD_CAGES=5 LOAD_DATES=5 php ops/load/seed.php   # quick smoke shape
 */

declare(strict_types=1);

use Illuminate\Contracts\Console\Kernel;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

$root = dirname(__DIR__, 2);
require $root.'/backend/vendor/autoload.php';
$app = require $root.'/backend/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

// --- configuration (env overrides keep the smoke run tiny) --------------------
$farmMarker = 'TERNAVA Load Test';
$cages = (int) (getenv('LOAD_CAGES') ?: 100);
$dates = (int) (getenv('LOAD_DATES') ?: 1000);
$users = (int) (getenv('LOAD_USERS') ?: 20);
$baseDate = new DateTimeImmutable(getenv('LOAD_BASE_DATE') ?: '2020-01-01');
$writeBaseDate = getenv('LOAD_WRITE_BASE_DATE') ?: '2023-01-01';
$expectedRecords = $cages * $dates;

$password = getenv('TERNAVA_LOAD_PASSWORD') ?: bin2hex(random_bytes(16));

$credentialsPath = $root.'/backend/storage/app/private/load/credentials.json';
@mkdir(dirname($credentialsPath), 0700, true);

printf("Seeding load fixtures: %d cages x %d dates = %d daily records, %d users\n",
    $cages, $dates, $expectedRecords, $users);

$farmId = (string) Str::uuid();
$feedTypeId = (string) Str::uuid();

// --- idempotency: drop any previous load farm (cascade removes children) ------
DB::table('farms')->where('name', 'like', $farmMarker.'%')->delete();

$now = now();

DB::table('farms')->insert([
    'id' => $farmId,
    'name' => $farmMarker,
    'location' => 'Load Test Synthetic',
    'timezone' => 'Asia/Jakarta',
    'currency' => 'IDR',
    'version' => 1,
    'updated_at' => $now,
]);

// --- users + memberships (one per VU so each gets its own rate budget) --------
$userIds = [];
$membershipIds = [];
$userRows = [];
$membershipRows = [];
$passwordHash = password_hash($password, PASSWORD_BCRYPT);
for ($u = 1; $u <= $users; $u++) {
    $uid = (string) Str::uuid();
    $mid = (string) Str::uuid();
    $userIds[] = $uid;
    $membershipIds[] = $mid;
    $userRows[] = [
        'id' => $uid,
        'username' => sprintf('loaduser%02d', $u),
        'display_name' => sprintf('Load User %02d', $u),
        'password_hash' => $passwordHash,
        'must_change_password' => false,
        'active' => true,
        'created_at' => $now,
        'updated_at' => $now,
    ];
    $membershipRows[] = [
        'id' => $mid,
        'farm_id' => $farmId,
        'user_id' => $uid,
        'role' => 'operator',
        'scope_version' => 1,
        'version' => 1,
        'active' => true,
    ];
}
DB::table('users')->insert($userRows);
DB::table('memberships')->insert($membershipRows);

// --- cages + flocks + assignments --------------------------------------------
$cageIds = [];
$flockIds = [];
$cageRows = [];
$flockRows = [];
$assignmentRows = [];
for ($c = 1; $c <= $cages; $c++) {
    $cid = (string) Str::uuid();
    $fid = (string) Str::uuid();
    $cageIds[] = $cid;
    $flockIds[] = $fid;
    $cageRows[] = [
        'id' => $cid,
        'farm_id' => $farmId,
        'code' => sprintf('K-%04d', $c),
        'name' => sprintf('Kandang %04d', $c),
        'active' => true,
        'version' => 1,
        'updated_at' => $now,
    ];
    $flockRows[] = [
        'id' => $fid,
        'farm_id' => $farmId,
        'cage_id' => $cid,
        'code' => sprintf('FL-%04d', $c),
        'placed_on' => $baseDate->format('Y-m-d'),
        'finished_on' => null,
        'initial_population' => 1000,
        'recorded_population' => 1000,
        'version' => 1,
        'updated_at' => $now,
    ];
    // Assign every load user to every cage so cage scoping never blocks reads.
    foreach ($membershipIds as $mid) {
        $assignmentRows[] = [
            'id' => (string) Str::uuid(),
            'farm_id' => $farmId,
            'membership_id' => $mid,
            'cage_id' => $cid,
        ];
    }
}
foreach (array_chunk($cageRows, 500) as $chunk) {
    DB::table('cages')->insert($chunk);
}
foreach (array_chunk($flockRows, 500) as $chunk) {
    DB::table('flocks')->insert($chunk);
}
foreach (array_chunk($assignmentRows, 1000) as $chunk) {
    DB::table('cage_assignments')->insert($chunk);
}

// --- feed type + balance ------------------------------------------------------
DB::table('feed_types')->insert([
    'id' => $feedTypeId,
    'farm_id' => $farmId,
    'code' => 'LT-01',
    'name' => 'Load Konsentrat',
    'minimum_kg' => '0.00',
    'active' => true,
    'version' => 1,
    'updated_at' => $now,
]);
DB::table('feed_balances')->insert([
    'id' => (string) Str::uuid(),
    'farm_id' => $farmId,
    'feed_type_id' => $feedTypeId,
    'quantity_kg' => '900000000000.00',
    'updated_at' => $now,
]);

// --- daily records + feed entries + sync changes ------------------------------
$seq = 0;
$written = 0;
$dailyChunk = [];
$feedChunk = [];
$changeChunk = [];

$flush = function (bool $force = false) use (&$dailyChunk, &$feedChunk, &$changeChunk, &$written) {
    if ($force || count($dailyChunk) >= 2000) {
        DB::table('daily_records')->insert($dailyChunk);
        DB::table('feed_entries')->insert($feedChunk);
        DB::table('sync_changes')->insert($changeChunk);
        $written += count($dailyChunk);
        $dailyChunk = [];
        $feedChunk = [];
        $changeChunk = [];
    }
};

for ($c = 0; $c < $cages; $c++) {
    $flockId = $flockIds[$c];
    for ($d = 0; $d < $dates; $d++) {
        $recordId = (string) Str::uuid();
        $businessDate = $baseDate->modify("+$d days")->format('Y-m-d');
        $acceptedAt = $baseDate->modify("+$d days")->format('Y-m-d H:i:sP');
        $seq++;

        $dailyChunk[] = [
            'id' => $recordId,
            'farm_id' => $farmId,
            'flock_id' => $flockId,
            'business_date' => $businessDate,
            'feed_type_id' => $feedTypeId,
            'feed_kg' => '12.50',
            'eggs_count' => 850,
            'mortality_count' => 0,
            'population_change' => null,
            'condition' => 'normal',
            'notes' => null,
            'version' => 1,
            'recorded_by' => $userIds[0],
            'accepted_at' => $acceptedAt,
            'updated_at' => $acceptedAt,
        ];
        $feedChunk[] = [
            'id' => (string) Str::uuid(),
            'farm_id' => $farmId,
            'feed_type_id' => $feedTypeId,
            'business_date' => $businessDate,
            'kind' => 'daily_usage',
            'delta_kg' => '12.50',
            'unit_price_idr' => null,
            'purchase_total_idr' => null,
            'supplier' => null,
            'reason' => null,
            'daily_record_id' => $recordId,
            'daily_version' => 1,
            'reverses_entry_id' => null,
            'accepted_at' => $acceptedAt,
        ];
        $changeChunk[] = [
            'id' => (string) Str::uuid(),
            'farm_id' => $farmId,
            'sequence' => $seq,
            'resource_type' => 'daily_record',
            'resource_id' => $recordId,
            'action' => 'upsert',
            'snapshot' => json_encode(['id' => $recordId, 'feed_kg' => '12.50']),
            'accepted_at' => $acceptedAt,
        ];
        $flush();
    }
    if ($c % 10 === 0) {
        fwrite(STDERR, sprintf("  ... %d/%d flocks, %d records\n", $c + 1, $cages, $written));
    }
}
$flush(true);

DB::table('sync_counters')->insert([
    'id' => (string) Str::uuid(),
    'farm_id' => $farmId,
    'last_sequence' => $seq,
]);

$credentials = [
    'farm_id' => $farmId,
    'feed_type_id' => $feedTypeId,
    'flock_ids' => $flockIds,
    'usernames' => array_map(fn ($u) => sprintf('loaduser%02d', $u), range(1, $users)),
    'password' => $password,
    'write_base_date' => $writeBaseDate,
    'daily_records' => $expectedRecords,
];
file_put_contents($credentialsPath, json_encode($credentials, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
chmod($credentialsPath, 0600);

printf("Done: %d daily records, %d feed entries, %d sync changes, %d users.\n",
    $expectedRecords, $expectedRecords, $seq, $users);
printf("Credentials written to a git-ignored runtime file (password not printed).\n");
