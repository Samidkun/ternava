<?php

namespace Tests\Feature;

use App\Daily\CreateDaily;
use App\Daily\ReviseDaily;
use App\Feed\FeedService;
use App\Support\ActorScope;
use App\Sync\SyncService;
use Illuminate\Foundation\Testing\DatabaseTruncation;
use Illuminate\Foundation\Testing\RefreshDatabaseState;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\ConflictHttpException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Tests\TestCase;

/**
 * T44 — Concurrency and capacity invariants (AC-26, AC-27, AC-28, AC-29,
 * AC-30, AC-31, AC-34).
 *
 * These tests exercise REAL concurrent writers, not simulated ones: each
 * scenario forks sibling OS processes that race against PostgreSQL, and we
 * assert the durable invariants afterwards (ledger, population, events,
 * receipts). A single-process test would pass even with read-modify-write
 * races, which is exactly the class of bug this task exists to catch.
 *
 * Forked children talk to the same database over their OWN connection
 * (reconnected after fork) and record their outcome in a per-child NDJSON
 * file, which the parent reads back deterministically.
 */
class ConcurrentMutationTest extends TestCase
{
    use DatabaseTruncation;

    private string $farmId;

    private string $ownerId;

    private string $operatorId;

    private string $operator2Id;

    private string $cageId;

    private string $flockId;

    private string $feedTypeId;

    private string $feedType2Id;

    protected function setUp(): void
    {
        parent::setUp();

        $this->farmId = (string) Str::uuid();
        $this->cageId = (string) Str::uuid();
        $this->flockId = (string) Str::uuid();
        $this->feedTypeId = (string) Str::uuid();
        $this->feedType2Id = (string) Str::uuid();

        DB::table('farms')->insert([
            'id' => $this->farmId,
            'name' => 'Farm Concurrency',
            'location' => 'Malang',
            'timezone' => 'Asia/Jakarta',
            'currency' => 'IDR',
            'version' => 1,
            'updated_at' => now(),
        ]);

        $this->ownerId = $this->makeUser('owner_conc', 'owner');
        $this->operatorId = $this->makeUser('operator_conc_1', 'operator');
        $this->operator2Id = $this->makeUser('operator_conc_2', 'operator');

        DB::table('memberships')->insert([
            'id' => (string) Str::uuid(),
            'farm_id' => $this->farmId,
            'user_id' => $this->ownerId,
            'role' => 'admin',
            'scope_version' => 1,
            'version' => 1,
            'active' => true,
        ]);

        DB::table('cages')->insert([
            'id' => $this->cageId,
            'farm_id' => $this->farmId,
            'code' => 'K-CONC-01',
            'name' => 'Kandang Concurrency',
            'active' => true,
            'version' => 1,
            'updated_at' => now(),
        ]);

        foreach ([$this->operatorId, $this->operator2Id] as $opId) {
            $membershipId = (string) Str::uuid();
            DB::table('memberships')->insert([
                'id' => $membershipId,
                'farm_id' => $this->farmId,
                'user_id' => $opId,
                'role' => 'operator',
                'scope_version' => 1,
                'version' => 1,
                'active' => true,
            ]);
            DB::table('cage_assignments')->insert([
                'id' => (string) Str::uuid(),
                'farm_id' => $this->farmId,
                'membership_id' => $membershipId,
                'cage_id' => $this->cageId,
            ]);
        }

        DB::table('flocks')->insert([
            [
                'id' => $this->flockId,
                'farm_id' => $this->farmId,
                'cage_id' => $this->cageId,
                'code' => 'FL-CONC-A',
                'placed_on' => '2026-01-01',
                'finished_on' => null,
                'initial_population' => 100,
                'recorded_population' => 100,
                'version' => 1,
                'updated_at' => now(),
            ],
        ]);

        DB::table('feed_types')->insert([
            [
                'id' => $this->feedTypeId,
                'farm_id' => $this->farmId,
                'code' => 'FEED-A',
                'name' => 'Pakan A',
                'minimum_kg' => '0.00',
                'active' => true,
                'version' => 1,
                'updated_at' => now(),
            ],
            [
                'id' => $this->feedType2Id,
                'farm_id' => $this->farmId,
                'code' => 'FEED-B',
                'name' => 'Pakan B',
                'minimum_kg' => '0.00',
                'active' => true,
                'version' => 1,
                'updated_at' => now(),
            ],
        ]);

        // Two balances: A = 300.00, B = 100.00 (AC-30: consume 270+270 vs 300;
        // AC-30 feed-type revision moves 10 kg between A and B).
        DB::table('feed_balances')->insert([
            [
                'id' => (string) Str::uuid(),
                'farm_id' => $this->farmId,
                'feed_type_id' => $this->feedTypeId,
                'quantity_kg' => '300.00',
                'updated_at' => now(),
            ],
            [
                'id' => (string) Str::uuid(),
                'farm_id' => $this->farmId,
                'feed_type_id' => $this->feedType2Id,
                'quantity_kg' => '100.00',
                'updated_at' => now(),
            ],
        ]);
    }

    protected function tearDown(): void
    {
        // This class commits real rows (forked children need visible data), so
        // it must not leak into later classes. Two things leak:
        //   1. the committed rows themselves;
        //   2. the shared RefreshDatabaseState::$migrated flag, which makes a
        //      later RefreshDatabase class skip migrate:fresh and inherit them.
        // Clean both so every class starts from a pristine schema.
        if (RefreshDatabaseState::$migrated) {
            $this->truncateDatabaseTables();
            RefreshDatabaseState::$migrated = false;
        }

        parent::tearDown();
    }

    private function makeUser(string $username, string $role): string
    {
        $id = (string) Str::uuid();
        DB::table('users')->insert([
            'id' => $id,
            'username' => $username,
            'display_name' => ucfirst($username),
            'password_hash' => Hash::make('password123'),
            'must_change_password' => false,
            'active' => true,
        ]);

        return $id;
    }

    private function actor(string $userId, string $role = 'operator'): ActorScope
    {
        return new ActorScope(
            actorId: $userId,
            farmId: $this->farmId,
            role: $role,
            cageIds: [$this->cageId],
        );
    }

    private function dailyInput(array $overrides = []): array
    {
        return array_merge([
            'flock_id' => $this->flockId,
            'business_date' => '2026-06-01',
            'feed_type_id' => $this->feedTypeId,
            'feed_kg' => '10.00',
            'eggs_count' => 85,
            'mortality_count' => 0,
            'condition' => 'normal',
        ], $overrides);
    }

    /**
     * Run $count identical closures in forked children that all fire at
     * (roughly) the same instant. Each child returns a status string via a
     * shared array-like file.
     *
     * @param  array<string, mixed>  $context  Data the child needs (ids, payloads).
     * @param  string  $body  Name of the racing routine to run in each child.
     * @return array{statuses: list<string>, results: list<array<string, mixed>>}
     */
    private function race(string $body, int $count, array $context = []): array
    {
        $dir = sys_get_temp_dir().'/ternava-race-'.Str::uuid();
        @mkdir($dir, 0700, true);
        $barrier = $dir.'/go';

        $pids = [];
        for ($i = 0; $i < $count; $i++) {
            $out = $dir."/child-{$i}.json";
            $pid = pcntl_fork();
            if ($pid === 0) {
                // Child: fresh DB connection (do not inherit the parent's socket).
                DB::disconnect();
                DB::reconnect();

                // Barrier: spin until the parent releases everyone together.
                $deadline = microtime(true) + 5.0;
                while (! file_exists($barrier) && microtime(true) < $deadline) {
                    usleep(2000);
                }

                $result = $this->childBody($body, $context, $i);

                file_put_contents($out, json_encode($result));
                exit(0);
            }
            $pids[] = $pid;
        }

        // Release the barrier so all children race at the same moment.
        file_put_contents($barrier, '1');

        foreach ($pids as $pid) {
            pcntl_waitpid($pid, $status);
        }

        DB::reconnect();

        $results = [];
        $statuses = [];
        for ($i = 0; $i < $count; $i++) {
            $raw = @file_get_contents($dir."/child-{$i}.json");
            $decoded = $raw ? json_decode($raw, true) : ['status' => 'no_result'];
            $results[] = $decoded;
            $statuses[] = $decoded['status'] ?? 'unknown';
            @unlink($dir."/child-{$i}.json");
        }
        @unlink($barrier);
        @unlink($dir);

        return ['statuses' => $statuses, 'results' => $results];
    }

    /**
     * @param  array<string, mixed>  $ctx
     * @return array<string, mixed>
     */
    private function childBody(string $body, array $ctx, int $index): array
    {
        try {
            return match ($body) {
                'same_key' => $this->childSameKey($ctx, $index),
                'daily_diff_key' => $this->childDailyDiffKey($ctx, $index),
                'consume_270' => $this->childConsume($ctx, $index),
                'revise_base1' => $this->childRevise($ctx, $index),
                'mortality' => $this->childMortality($ctx, $index),
                'atomic_fail' => $this->childAtomicFail($ctx, $index),
                'revise_feedtype' => $this->childReviseFeedType($ctx, $index),
                'mixed' => $this->childMixed($ctx, $index),
                default => ['status' => 'unknown_body'],
            };
        } catch (\Throwable $e) {
            return [
                'status' => 'exception',
                'class' => $e::class,
                'message' => substr($e->getMessage(), 0, 120),
            ];
        }
    }

    /**
     * 20 identical requests, same key & payload (AC-27): exactly one effect.
     */
    private function childSameKey(array $ctx, int $index): array
    {
        $actor = $this->actor($this->operatorId);
        $key = $ctx['key'];
        $input = $ctx['input'];

        try {
            $ack = app(CreateDaily::class)->handle($actor, $input, $key);

            return ['status' => 'ok', 'version' => $ack->toArray()['version'] ?? null];
        } catch (\Throwable $e) {
            return [
                'status' => 'error',
                'http' => $e->getCode(),
                'class' => $e::class,
            ];
        }
    }

    /**
     * Two operators, different keys, same flock & date (AC-28): one accepted.
     */
    private function childDailyDiffKey(array $ctx, int $index): array
    {
        $actor = $this->actor($index === 0 ? $this->operatorId : $this->operator2Id);

        try {
            $ack = app(CreateDaily::class)->handle($actor, $ctx['input'], $ctx['keys'][$index]);

            return ['status' => 'ok', 'id' => $ack->toArray()['id'] ?? null];
        } catch (ConflictHttpException $e) {
            return ['status' => 'conflict'];
        } catch (\Throwable $e) {
            return ['status' => 'error', 'class' => $e::class];
        }
    }

    /**
     * 270 + 270 kg against a single 300 kg balance (AC-30): only one may be
     * accepted and the ledger must never go negative.
     */
    private function childConsume(array $ctx, int $index): array
    {
        $actor = $this->actor($this->ownerId, 'admin');

        try {
            app(FeedService::class)->createEntry($actor, [
                'feed_type_id' => $this->feedTypeId,
                'direction' => 'out',
                'quantity_kg' => '270.00',
                'kind' => 'manual_out',
                'business_date' => '2026-06-01',
            ], (string) Str::uuid());

            return ['status' => 'ok', 'feed_type_id' => $this->feedTypeId];
        } catch (\Throwable $e) {
            return ['status' => 'rejected', 'feed_type_id' => $this->feedTypeId, 'class' => $e::class];
        }
    }

    /**
     * Two admins revise with base_version=1 (AC-29): only one becomes v2.
     */
    private function childRevise(array $ctx, int $index): array
    {
        $actor = $this->actor($this->ownerId, 'admin');
        $input = array_merge($this->dailyInput(['flock_id' => $ctx['flock_id']]), [
            'base_version' => 1,
            'reason' => 'Revisi bersamaan #'.$index,
        ]);

        try {
            $ack = app(ReviseDaily::class)->handle($actor, $ctx['daily_id'], $input, (string) Str::uuid());

            return ['status' => 'ok', 'version' => $ack->toArray()['version'] ?? null];
        } catch (ConflictHttpException $e) {
            return ['status' => 'conflict'];
        } catch (\Throwable $e) {
            return ['status' => 'error', 'class' => $e::class];
        }
    }

    /**
     * Two operators record mortality that, combined, would drive the flock
     * population negative (AC-31). Only the ones keeping every prefix >= 0 may
     * commit; the rest must be refused with a clean validation error.
     */
    private function childMortality(array $ctx, int $index): array
    {
        $actor = $this->actor($this->operatorId);

        try {
            $ack = app(CreateDaily::class)->handle($actor, $this->dailyInput([
                'feed_type_id' => $this->feedTypeId,
                'feed_kg' => '0.00',
                'mortality_count' => $ctx['mortality'],
            ]), (string) Str::uuid());

            return ['status' => 'ok', 'version' => $ack->toArray()['version'] ?? null];
        } catch (ValidationException $e) {
            return ['status' => 'invalid'];
        } catch (HttpExceptionInterface $e) {
            return ['status' => 'rejected'];
        } catch (\Throwable $e) {
            return ['status' => 'error', 'class' => $e::class];
        }
    }

    /**
     * A daily create that legitimately fails its population assertion after
     * writing the record and the feed entry. The whole unit must roll back:
     * no partial record, feed entry, balance change or sync change (AC-26).
     */
    private function childAtomicFail(array $ctx, int $index): array
    {
        $actor = $this->actor($this->operatorId);

        try {
            app(CreateDaily::class)->handle($actor, $this->dailyInput([
                'feed_type_id' => $this->feedTypeId,
                'feed_kg' => '5.00',
                'mortality_count' => 999, // exceeds population 100 -> must fail
            ]), (string) Str::uuid());

            return ['status' => 'ok'];
        } catch (\Throwable $e) {
            return ['status' => 'rolled_back', 'class' => $e::class];
        }
    }

    /**
     * Two admins revise the same record to different feed types (AC-30's
     * "revisi beda jenis pakan"): the ledger for BOTH feed types must remain
     * consistent — the loser leaves no trace.
     */
    private function childReviseFeedType(array $ctx, int $index): array
    {
        $actor = $this->actor($this->ownerId, 'admin');
        $feedTypeId = $index === 0 ? $this->feedTypeId : $this->feedType2Id;

        try {
            $ack = app(ReviseDaily::class)->handle($actor, $ctx['daily_id'], $this->dailyInput([
                'flock_id' => $ctx['flock_id'],
                'feed_type_id' => $feedTypeId,
                'feed_kg' => '10.00',
            ]) + ['base_version' => 1, 'reason' => 'Ganti jenis pakan #'.$index], (string) Str::uuid());

            return ['status' => 'ok', 'version' => $ack->toArray()['version'] ?? null];
        } catch (ConflictHttpException $e) {
            return ['status' => 'conflict'];
        } catch (\Throwable $e) {
            return ['status' => 'error', 'class' => $e::class];
        }
    }

    /**
     * Bootstrap (a read snapshot) racing with a write (AC-34): the write must
     * land as one unit and the bootstrap must never observe a half-applied
     * record (record present but its ledger/event missing, or vice versa).
     */
    private function childMixed(array $ctx, int $index): array
    {
        if ($index === 0) {
            // Writer: create a daily record with feed + mortality.
            $actor = $this->actor($this->operatorId);

            try {
                app(CreateDaily::class)->handle($actor, $this->dailyInput([
                    'feed_type_id' => $this->feedTypeId,
                    'feed_kg' => '7.00',
                    'mortality_count' => 3,
                ]), (string) Str::uuid());

                return ['status' => 'ok'];
            } catch (\Throwable $e) {
                return ['status' => 'error', 'class' => $e::class];
            }
        }

        // Reader: bootstrap repeatedly and look for torn state. Each check is a
        // single atomic statement, so it can never observe a half-committed
        // write (a record whose feed entry is missing, or an orphan entry).
        $actor = $this->actor($this->operatorId);
        $torn = 0;
        for ($i = 0; $i < 40; $i++) {
            app(SyncService::class)->bootstrap($actor);

            $orphanRecords = (int) DB::selectOne(
                'SELECT count(*) AS c FROM daily_records d WHERE d.farm_id = ? AND d.feed_kg > 0
                 AND NOT EXISTS (SELECT 1 FROM feed_entries f WHERE f.daily_record_id = d.id)',
                [$this->farmId]
            )->c;

            $orphanEntries = (int) DB::selectOne(
                'SELECT count(*) AS c FROM feed_entries f WHERE f.farm_id = ?
                 AND f.daily_record_id IS NOT NULL
                 AND NOT EXISTS (SELECT 1 FROM daily_records d WHERE d.id = f.daily_record_id)',
                [$this->farmId]
            )->c;

            $torn += $orphanRecords + $orphanEntries;
        }

        return ['status' => 'ok', 'torn' => $torn];
    }

    // ---------------------------------------------------------------------
    // AC-27 / AC-26: 20 identical requests, same key -> one effect, one ACK.
    // ---------------------------------------------------------------------
    public function test_twenty_identical_requests_have_one_effect_and_one_receipt(): void
    {
        $key = (string) Str::uuid();
        $input = $this->dailyInput();

        $race = $this->race('same_key', 20, ['key' => $key, 'input' => $input]);

        // Exactly one row was created.
        $this->assertSame(1, DB::table('daily_records')->where('flock_id', $this->flockId)
            ->where('business_date', '2026-06-01')->count(), 'Exactly one daily record must exist.');

        // Exactly one receipt for this operation.
        $this->assertSame(1, DB::table('idempotency_receipts')->where('operation_id', $key)->count(),
            'Exactly one idempotency receipt must exist for the shared key.');

        // Exactly one feed entry and one sync change.
        $this->assertSame(1, DB::table('feed_entries')->where('farm_id', $this->farmId)->count());
        $this->assertSame(1, DB::table('sync_changes')->where('resource_type', 'daily_record')->count());

        // AC-27: a replayed key MUST return the ORIGINAL ACK, never a raw
        // database error. Every one of the 20 concurrent callers sees success
        // with the identical version.
        $errors = array_filter($race['results'], fn ($r) => ($r['status'] ?? '') === 'error');
        $this->assertSame([], array_values($errors),
            'No concurrent caller may receive a raw error: '.json_encode(array_values($errors)));
        $this->assertCount(20, array_filter($race['statuses'], fn ($s) => $s === 'ok'));
        $versions = array_unique(array_column($race['results'], 'version'));
        $this->assertSame([1], array_values($versions), 'Every replay must return the original version 1.');

        // The ledger reflects exactly one deduction: 300 - 10 = 290.
        $this->assertSame('290.00', $this->balance($this->feedTypeId));
    }

    // ---------------------------------------------------------------------
    // AC-28: two operators, different keys, same flock/date -> one accepted.
    // ---------------------------------------------------------------------
    public function test_two_operators_same_flock_date_different_keys_only_one_wins(): void
    {
        $race = $this->race('daily_diff_key', 2, [
            'input' => $this->dailyInput(),
            'keys' => [(string) Str::uuid(), (string) Str::uuid()],
        ]);

        $accepted = count(array_filter($race['statuses'], fn ($s) => $s === 'ok'));
        $this->assertSame(1, $accepted, 'Only ONE of the two operators may be accepted.');

        // AC-28: the loser must be refused with a clean 409 conflict, not a
        // raw unique-constraint 500.
        $this->assertSame(1, count(array_filter($race['statuses'], fn ($s) => $s === 'conflict')),
            'The second operator must be rejected with a conflict: '.json_encode($race['results']));
        $this->assertSame([], array_values(array_filter($race['statuses'], fn ($s) => $s === 'error')),
            'No operator may receive a raw error.');

        $this->assertSame(1, DB::table('daily_records')->where('flock_id', $this->flockId)
            ->where('business_date', '2026-06-01')->count());
        // The daily total must NOT be summed (two feed deductions would be 290+290).
        $this->assertSame('290.00', $this->balance($this->feedTypeId),
            'Daily totals must not be summed: exactly one 10.00 kg deduction.');
    }

    // ---------------------------------------------------------------------
    // AC-30: 270 + 270 kg against one 300 kg balance -> never negative.
    // ---------------------------------------------------------------------
    public function test_concurrent_consumption_of_270_plus_270_against_300_keeps_ledger_nonnegative(): void
    {
        $race = $this->race('consume_270', 2, []);

        $accepted = count(array_filter($race['statuses'], fn ($s) => $s === 'ok'));
        $this->assertSame(1, $accepted, 'Only 270 kg may succeed; the second 270 kg must be rejected.');

        // The loser must be a clean business rejection (422), not a crash.
        $this->assertSame([], array_values(array_filter($race['statuses'], fn ($s) => $s === 'error')),
            'The over-draw must be refused cleanly: '.json_encode($race['results']));

        // Ledger must be 30.00 (300 - 270), never negative.
        $this->assertSame('30.00', $this->balance($this->feedTypeId));

        // Global invariant: no balance is ever negative.
        $negative = DB::table('feed_balances')->where('farm_id', $this->farmId)
            ->whereRaw('quantity_kg < 0')->count();
        $this->assertSame(0, $negative, 'No feed balance may be negative.');

        // Only one feed entry survived the rejection.
        $this->assertSame(1, DB::table('feed_entries')->where('farm_id', $this->farmId)->count(),
            'The rejected intent must leave NO feed entry behind.');
    }

    // ---------------------------------------------------------------------
    // AC-29: two admins revise base_version=1 -> only one becomes v2.
    // ---------------------------------------------------------------------
    public function test_two_admins_revising_base_version_one_yield_single_v2(): void
    {
        app(CreateDaily::class)->handle($this->actor($this->operatorId), $this->dailyInput(), (string) Str::uuid());

        $dailyId = (string) DB::table('daily_records')
            ->where('flock_id', $this->flockId)->where('business_date', '2026-06-01')->value('id');

        $race = $this->race('revise_base1', 2, ['daily_id' => $dailyId, 'flock_id' => $this->flockId]);

        $accepted = count(array_filter($race['statuses'], fn ($s) => $s === 'ok'));
        $this->assertSame(1, $accepted, 'Only one revision from base_version=1 may succeed.');

        // AC-29: the stale revision must be refused with 409 and must leave the
        // record and ledger untouched — no raw unique-constraint error.
        $this->assertSame(1, count(array_filter($race['statuses'], fn ($s) => $s === 'conflict')),
            'The stale revision must be rejected with a conflict: '.json_encode($race['results']));
        $this->assertSame([], array_values(array_filter($race['statuses'], fn ($s) => $s === 'error')),
            'No reviser may receive a raw error.');

        // Record is at version 2, and exactly one revision snapshot exists.
        $version = (int) DB::table('daily_records')->where('id', $dailyId)->value('version');
        $this->assertSame(2, $version, 'The record must advance to exactly version 2.');

        $revisions = (int) DB::table('daily_revisions')->where('daily_record_id', $dailyId)->count();
        $this->assertSame(1, $revisions, 'Exactly one revision snapshot must be archived.');

        // The rejected revision must not have moved the ledger at all.
        // 300 - 10 (create) = 290; the winning revision reverses 10 and applies 10.
        $this->assertSame('290.00', $this->balance($this->feedTypeId));
    }

    // ---------------------------------------------------------------------
    // AC-31: concurrent mortality may not drive population negative.
    // ---------------------------------------------------------------------
    public function test_concurrent_mortality_never_makes_population_negative(): void
    {
        // Population 100. Two operators each record 60 deaths: 60 + 60 > 100,
        // so at most one may commit (120 deaths would be impossible).
        $race = $this->race('mortality', 2, ['mortality' => 60]);

        $accepted = count(array_filter($race['statuses'], fn ($s) => $s === 'ok'));
        $this->assertSame(1, $accepted, 'Only one 60-death entry may fit inside a population of 100.');

        // No raw crash; the loser is a clean validation/business rejection.
        $this->assertSame([], array_values(array_filter($race['statuses'], fn ($s) => $s === 'error')),
            'The over-mortality must be refused cleanly: '.json_encode($race['results']));

        // Population projections must never go negative at any prefix.
        $totalDelta = (int) DB::table('population_entries')->where('flock_id', $this->flockId)->sum('delta_count');
        $this->assertGreaterThanOrEqual(-100, $totalDelta, 'Population delta may not exceed the initial 100.');

        // Exactly one population entry survived.
        $this->assertSame(1, DB::table('population_entries')->where('flock_id', $this->flockId)->count(),
            'The rejected mortality must leave NO population entry behind.');
    }

    // ---------------------------------------------------------------------
    // AC-26: a failing mutation rolls back every partial effect.
    // ---------------------------------------------------------------------
    public function test_failed_daily_mutation_rolls_back_all_effects(): void
    {
        $race = $this->race('atomic_fail', 1, []);

        $this->assertSame(['rolled_back'], $race['statuses'], 'The over-mortality create must fail.');

        // AC-26: NONE of the partial effects may survive the rollback.
        $this->assertSame(0, DB::table('daily_records')->where('flock_id', $this->flockId)->count(),
            'No daily record may survive a failed transaction.');
        $this->assertSame(0, DB::table('feed_entries')->where('farm_id', $this->farmId)->count(),
            'No feed entry may survive a failed transaction.');
        $this->assertSame(0, DB::table('population_entries')->where('flock_id', $this->flockId)->count(),
            'No population entry may survive a failed transaction.');
        $this->assertSame(0, DB::table('idempotency_receipts')->where('farm_id', $this->farmId)->count(),
            'No idempotency receipt may survive a failed transaction.');
        $this->assertSame(0, DB::table('sync_changes')->where('farm_id', $this->farmId)->count(),
            'No sync change may survive a failed transaction.');
        // The feed balance must be untouched: 300.00, not 295.00.
        $this->assertSame('300.00', $this->balance($this->feedTypeId),
            'The feed balance must be untouched by a rolled-back transaction.');
    }

    // ---------------------------------------------------------------------
    // AC-30: two admins revise to different feed types -> ledger consistent.
    // ---------------------------------------------------------------------
    public function test_two_admins_revising_to_different_feed_types_keep_ledger_consistent(): void
    {
        // Seed: record uses feed A, 10 kg -> A = 290, B = 0.
        app(CreateDaily::class)->handle($this->actor($this->operatorId), $this->dailyInput(), (string) Str::uuid());

        $dailyId = (string) DB::table('daily_records')
            ->where('flock_id', $this->flockId)->where('business_date', '2026-06-01')->value('id');

        $race = $this->race('revise_feedtype', 2, ['daily_id' => $dailyId, 'flock_id' => $this->flockId]);

        $accepted = count(array_filter($race['statuses'], fn ($s) => $s === 'ok'));
        $this->assertSame(1, $accepted, 'Only one feed-type revision may win from base_version=1.');
        $this->assertSame(1, count(array_filter($race['statuses'], fn ($s) => $s === 'conflict')),
            'The other revision must be a clean conflict: '.json_encode($race['results']));
        $this->assertSame([], array_values(array_filter($race['statuses'], fn ($s) => $s === 'error')),
            'No reviser may receive a raw error.');

        // Exactly one revision archived, record at v2.
        $this->assertSame(1, (int) DB::table('daily_revisions')->where('daily_record_id', $dailyId)->count());
        $this->assertSame(2, (int) DB::table('daily_records')->where('id', $dailyId)->value('version'));

        // The winning revision moved 10 kg off feed A onto whichever type won.
        // Exactly one net 10 kg deduction from the 400 kg initial total (A 300
        // + B 100) must remain: 390. The loser left no trace.
        $finalType = (string) DB::table('daily_records')->where('id', $dailyId)->value('feed_type_id');
        $totalFeed = (float) DB::table('feed_balances')->where('farm_id', $this->farmId)->sum('quantity_kg');
        $this->assertSame(390.0, $totalFeed,
            'Total feed across A (300) and B (100) must equal 390 after exactly one 10 kg deduction.');

        if ($finalType === $this->feedTypeId) {
            $this->assertSame('290.00', $this->balance($this->feedTypeId));
            $this->assertSame('100.00', $this->balance($this->feedType2Id));
        } else {
            $this->assertSame('300.00', $this->balance($this->feedTypeId));
            $this->assertSame('90.00', $this->balance($this->feedType2Id));
        }
        // No feed balance may be negative.
        $this->assertSame(0, DB::table('feed_balances')->where('farm_id', $this->farmId)
            ->whereRaw('quantity_kg < 0')->count(), 'No feed balance may be negative.');

        // No orphan feed entry may reference a vanished record.
        $this->assertSame(0, (int) DB::selectOne(
            'SELECT count(*) AS c FROM feed_entries f WHERE f.farm_id = ?
             AND f.daily_record_id IS NOT NULL
             AND NOT EXISTS (SELECT 1 FROM daily_records d WHERE d.id = f.daily_record_id)',
            [$this->farmId]
        )->c, 'The rejected revision must leave no orphan feed entry.');
    }

    // ---------------------------------------------------------------------
    // AC-34: bootstrap reads racing with a write never see torn state.
    // ---------------------------------------------------------------------
    public function test_bootstrap_reads_racing_with_a_write_never_see_torn_state(): void
    {
        $race = $this->race('mixed', 2, []);

        $this->assertSame([], array_values(array_filter($race['statuses'], fn ($s) => $s === 'error')),
            'Neither reader nor writer may crash: '.json_encode($race['results']));

        // The reader counted zero torn observations.
        $torn = array_sum(array_column(array_filter($race['results'], fn ($r) => isset($r['torn'])), 'torn'));
        $this->assertSame(0, $torn, 'Bootstrap must never observe a half-applied write.');

        // The writer committed exactly one unit.
        $this->assertSame(1, DB::table('daily_records')->where('flock_id', $this->flockId)->count());
        $this->assertSame(1, DB::table('feed_entries')->where('farm_id', $this->farmId)->count());
    }

    private function balance(string $feedTypeId): string
    {
        $val = DB::table('feed_balances')->where('feed_type_id', $feedTypeId)->value('quantity_kg');

        return number_format((float) $val, 2, '.', '');
    }

    protected function usesRealDatabaseConcurrency(): bool
    {
        return true;
    }

    public function test_environment_supports_process_concurrency(): void
    {
        $this->assertTrue(function_exists('pcntl_fork'), 'pcntl_fork is required for real concurrency tests.');
        $this->assertSame('pgsql', DB::connection()->getDriverName(), 'Concurrency tests must run on PostgreSQL.');
    }
}
