# Evidence — Concurrency dan benchmark kapasitas (Task T44)

Tanggal: 2 Oktober 2026
Acceptance: AC-26, AC-27, AC-28, AC-29, AC-30, AC-31, AC-34, AC-44
Commit dasar: `946b489` (T43) + working tree T44
Environment: host Linux 12 vCPU / 15 GiB; API = image `ternava-api` (PHP 8.4.26-alpine,
`pcntl` + `posix` + `pdo_pgsql`) dibatasi **2 vCPU / 4 GiB** lewat cgroup
(`NanoCpus=2000000000`, `Memory=4294967296`, `cpu.max=200000 100000`), dijalankan
`php -S` dengan 8 worker; PostgreSQL 18 (`ternava-postgres-1`); k6 v0.54.0.
Semua nilai kredensial di-redact.

## 1. Verify command (per plan T44)

| Perintah | Hasil | Catatan |
|---|---|---|
| `docker compose run --rm api php artisan test --filter=ConcurrentMutationTest` | **9 passed / 52 assertions** | dijalankan di dalam image, `pcntl`/`posix` terpasang sehingga fork test benar-benar jalan |
| `k6 run ops/load/benchmark.js` | lihat §3 | 20 VU, 15 menit, batas 2 vCPU / 4 GiB |

Sebelum T44, `backend/Dockerfile` **tidak** memuat `pcntl`/`posix`, sehingga
`php artisan test` di dalam kontainer akan men-*skip* fork test dan melaporkan
hijau palsu. Dockerfile kini memasang keduanya (commit ini).

## 2. Concurrency (AC-26, AC-27, AC-28, AC-29, AC-30, AC-31, AC-34)

Test memakai **proses OS nyata** (`pcntl_fork`), bukan simulasi: tiap skenario
mem-fork child yang masing-masing `DB::disconnect()`/`reconnect()` lalu menulis ke
PostgreSQL nyata secara bersamaan; hasil tiap child ditulis ke file NDJSON per-child
dan dibaca balik deterministik oleh parent.

> Catatan implementasi: kelas ini memakai trait `DatabaseTruncation` (bukan
> `RefreshDatabase`) karena data harus benar-benar ter-commit agar terlihat oleh
> child fork. `tearDown()` men-truncate tabel **dan** me-reset flag global
> `RefreshDatabaseState::$migrated` supaya kelas `RefreshDatabase` berikutnya tidak
> mewarisi baris T44 (bug polusi antar-kelas yang ditemukan & diperbaiki di sini).

### 2.1 Tiga cacat nyata yang ditemukan (RED → GREEN)

RED awal mengungkap tiga pelanggaran kontrak, bukan error environment:

| # | Skenario | Perilaku salah (sebelum) | Perbaikan | AC |
|---|---|---|---|---|
| 1 | 20 request key idempoten sama | 19/20 child dapat `SQLSTATE 23505` mentah → HTTP 500 | `MutationExecutor::run` menulis di `DB::transaction(..., 3)`; pada unique-violation, jika receipt key sama sudah ter-commit, kembalikan **ACK asli** | AC-27 |
| 2 | Dua operator, flock+tanggal sama, key beda | operator kedua dapat unique-violation mentah | `CreateDaily` menangkap `UniqueConstraintViolationException` → `ConflictHttpException` **409 DAILY_ALREADY_EXISTS** | AC-28 |
| 3 | Dua admin revisi `base_version=1` | yang kalah dapat `23505` di `daily_revisions_daily_record_id_version_unique` | `ReviseDaily` menangkap unique-violation revisi → **409** (versi terkini sebagai pesan) | AC-29 |

### 2.2 Cakupan assertion (9 test / 52 assertion)

| Test | AC | Invariant yang diperiksa |
|---|---|---|
| `twenty_identical_requests_have_one_effect_and_one_receipt` | AC-27 | 1 efek, 1 receipt, semua replay = ACK id sama |
| `two_operators_same_flock_date_different_keys_only_one_wins` | AC-28 | tepat 1 diterima, yang lain **409**, tanpa error mentah |
| `concurrent_consumption_of_270_plus_270_against_300_keeps_ledger_nonnegative` | AC-30 | tepat 1 diterima, saldo akhir `30.00`, tak ada `quantity_kg < 0` |
| `two_admins_revising_base_version_one_yield_single_v2` | AC-29 | tepat 1 jadi v2, kalah **409**, ledger tak bergeser (`290.00`) |
| `concurrent_mortality_never_makes_population_negative` | AC-31 | ≤1 entri lolos, tak ada populasi negatif di prefix mana pun |
| `failed_daily_mutation_rolls_back_all_effects` | AC-26 | rollback penuh: tak ada record/entry/populasi/receipt/sync change tertinggal |
| `two_admins_revising_to_different_feed_types_keep_ledger_consistent` | AC-30 | tepat 1 menang, total ledger konsisten, tanpa entri yatim |
| `bootstrap_reads_racing_with_a_write_never_see_torn_state` | AC-34 | 0 observasi torn (record tanpa entry / entry yatim) |
| `environment_supports_process_concurrency` | — | `pcntl_fork` ada & driver `pgsql` |

Stabilitas: `--filter=ConcurrentMutationTest` dijalankan **8×** berturut → **8/8 hijau**
(bukan flaky). Full suite backend **135/135 hijau** (tanpa regresi).

## 3. Capacity benchmark (AC-44)

**Fixture** (generator sintetis, bukan data produksi) via `ops/load/seed.php`:
1 farm, **100 cage/flock**, 1 feed type, **100 × 1000 = 100.000 `daily_records`**
(masing-masing dengan `feed_entries` + `sync_changes`), 20 user (1 token per VU).
Rentang tanggal seed: 2020-01-01 .. 2022-09-26.

**Beban**: `ops/load/benchmark.js` — 20 VU, 15 menit, tiap iterasi = 3 read
(`daily-records`, `sync/bootstrap`, `feed-balances`) + 1 write (`POST daily-records`
dengan `Idempotency-Key` UUID) + 1 replay key sama. Tiap VU login sebagai user sendiri
agar budget rate-limit terpisah; laju dijaga di bawah batas terdokumentasi
(120 req/menit/user) sehingga `rate_limited` harus 0.

**Batas sumber daya**: API dibatasi cgroup **2 vCPU / 4 GiB** (`cpu.max=200000 100000`,
`Memory=4294967296`).

### Hasil (dari `/tmp/t44-k6-full2.log`, setelah perbaikan pagination)

```
checks.........................: 100.00% 19800 out of 19800
http_req_failed................: 0.00%   0 out of 33020
http_reqs......................: 33020   36.5/s
iterations.....................: 6600    7.30/s
✓ read_duration................: avg=183.65ms p(90)=278.02ms p(95)=289.46ms p(99)=328.09ms max=752.68ms
✓ write_duration...............: avg=256.34ms p(90)=300.82ms p(95)=309.21ms p(99)=368.38ms max=458.27ms
✓ unexpected_error.............: 0
✓ duplicate_effect.............: 0
✓ rate_limited.................: 0
```

| Target AC-44 | Ambang | Hasil | Status |
|---|---|---|---|
| p95 read | ≤ 500 ms | **289 ms** | PASS |
| p95 write | ≤ 1 s | **309 ms** | PASS |
| unexpected error | < 1% | **0%** (0/33.020) | PASS |
| efek duplikat | 0 | **0** | PASS |
| rate-limited (di luar budget) | 0 | **0** | PASS |

Pemakaian sumber daya kontainer saat beban puncak: memori ~64 MiB dari 4 GiB.

### Cacat nyata yang ditemukan benchmark (RED → GREEN)

Run pertama **gagal**: p95 read = **1,19 s** (melewati 500 ms) dan sebagian request
`500` (`Allowed memory size ... exhausted`) pada kontainer ber-memori 128 MB. Akar
masalahnya bukan kapasitas, melainkan cacat kontrak:

- `GET /daily-records` **mengabaikan** parameter `limit` (1..100) dan `cursor` yang
  dideklarasikan `openapi.json`, serta memakai `from_date`/`to_date` padahal kontrak
  menetapkan `from`/`to`. Endpoint mengembalikan **seluruh** baris farm (15.300 baris
  untuk rentang uji) alih-alih maksimum 100 sesuai skema `DailyPage`.
- Perbaikan: `DailyController::index` kini memvalidasi `limit`/`cursor`/`from`/`to`,
  memakai **keyset pagination** (`business_date DESC, id DESC`) dengan `limit+1` untuk
  `has_more`, dan membalas `{data, meta{next_cursor,has_more,as_of}}` sesuai skema.
  Cursor mengikat filter (`scope`) sehingga mengubah filter menaikkan `409`.
- Test RED→GREEN: `backend/tests/Feature/DailyListPaginationTest.php` (**4 test / 16
  assertion**). Setelah perbaikan p95 read turun ke **289 ms**.

## 4. Batasan jujur (tidak diklaim lulus)

- **Cacat pagination hanya diperbaiki di `GET /daily-records`** (endpoint yang
  menyebabkan kegagalan AC-44). 14 endpoint list lain (`/cages`, `/flocks`,
  `/members`, `/feed-types`, `/feed-balances`, `/feed-entries`,
  `/daily-records/{id}/revisions`, `/task-runs`, `/incidents`, `/attachments`,
  `/inbox`, dll.) **juga** mendeklarasikan `limit`/`cursor` di `openapi.json` tetapi
  **belum** mengimplementasikannya — pola unbounded-read yang sama masih ada. Ini
  gap sistemik yang dicatat, bukan diklaim selesai.
- **Single host.** Benchmark berjalan di satu mesin (host + kontainer API + PostgreSQL
  di host yang sama); belum menguji jaringan nyata, load balancer, atau read replica.
- **PHP built-in server.** API memakai `php -S` (dev server) dengan 8 worker, bukan
  php-fpm + nginx. Angka latency berlaku untuk konfigurasi ini, bukan produksi
  yang di-tuning.
- **Data sintetis.** 100k baris dibuat generator; pola akses/ukuran payload tidak
  identik dengan dataset produksi (mis. foto attachment, riwayat panjang).
- **Write ke DB yang sama** dengan read; tidak ada pemisahan replica.
- **Angka p95 write dari dev server** mungkin lebih longgar daripada fpm; klaim hanya
  sebatas lingkungan yang diuji.
