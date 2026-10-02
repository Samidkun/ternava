# TERNAVA MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> **Batas pengguna D-012:** dokumen ini hanya planning. Jangan mulai task, scaffold, install SDK, coding, commit aplikasi atau deployment sampai pengguna meminta eksekusi. Penyebutan workflow agent bukan izin dispatch.

**Goal:** Membangun MVP Android agar operator ayam petelur dapat menyimpan total harian, tugas dan temuan secara offline, lalu pengelola meninjau accepted data, ledger dan laporan.

**Architecture:** Flutter MVVM/ChangeNotifier dengan repository, encrypted Drift cache/outbox dan REST API typed. Laravel modular monolith memakai PostgreSQL, Sanctum, transaction/receipt/counter, private uploads serta worker/scheduler DB queue. Semua ACK menunjukkan commit server; inbox durable tetap tersedia jika FCM gagal.

**Tech Stack:** Flutter stable/Dart (patch direkam T01), Drift/SQLite, cryptography AES-GCM/platform secure store, Laravel 13/PHP 8.4, PostgreSQL 18, Docker lokal, FCM optional. Dependencies/pinned tool versions ditetapkan terhadap versi nyata sebelum feature code, tidak ditebak dalam planning.

**Spec:** [2026-10-01-ternava-design.md](../specs/2026-10-01-ternava-design.md), diterima D-011; API/sync, operations-security, DESIGN dan contracts adalah bagian normatifnya.

## Global Constraints

Bagian berikut disalin verbatim dari spec dan dokumen arsitektur normatif yang dirujuknya:

Android, bahasa Indonesia, tema terang, satu farm contoh (Asia/Jakarta/IDR), sampai20 kandang/10 akun/20 perangkat sebagai kapasitas template. Owner/admin/operator, satu gudang pusat, satu cohort per kandang per tanggal. Tanggal/rentang/kuantitas mengikuti `api-sync.md`; angka ini ruling desain untuk review, bukan fakta farm. Kondisi medis diinput pengamatan manual, tidak otomatis didiagnosis. Field jumlah wajib untuk kirim, nol eksplisit, draft boleh belum lengkap; satu harian adalah total, bukan event per shift.

Termasuk: akses/setup, kandang/cohort, role/assignment, total harian+revisi, stok/receipt/adjustment, tugas/SOP+hasil, temuan/action, foto privat, inbox/push, ringkasan/reportCSV, offlinequeue dan akun. Tidak termasuk: dashboardweb, onboardingcarousel, signup publik, individu tiap ayam, transfer gudang, IoT/AI, diagnosis/dosis, akuntansi/laba, PDF, chat, pembayaran, iOS/PlayStore release. Splash hanya transisi awal, bukan scope halaman marketing.

Kebijakan sesi/role/revisi/retensi/reliability di `api-sync.md` dan `operations-security.md` merupakan bagian spesifikasi yang diterima melalui D-011. Deployment nyata menunggu gate AC-47; development lokal boleh memakai data rekaan. Tenggat/anggaran proyek tidak ditebak. Provider berbayar dan kontak petugas nyata ditetapkan sebelum deployment, sesuai D-010.


`DESIGN.md` normatif untuk tokens/hierarchy/spacing/behavior. Flutter merealisasikannya melalui widgets native; HTML tetap bukti visual, bukan code yang ditransplantasi literal. Fira Sans 400/600, primary #195647, body 16, target 48 dp, light background #F2F6F3; warna status disertai teks/icon. Baris kandang menampilkan status bertanggal. Angka contoh tidak diprefill pada form operasional baru. Motion 140 ms menghormati preferensi pengurangan motion. Kontras body 4.5:1, teks 200%/TalkBack diuji di Android. Preview controls AC-900 tidak masuk aplikasi.

Laravel **13**, PHP **8.4**, PostgreSQL **18** merupakan keluarga runtime rancangan. Laravel 13 mendukung PHP 8.3–8.5 menurut [release notes resmi](https://laravel.com/framework/docs/13.x/releases). Versi patch Flutter stable, Dart, plugin, Composer packages dan digest image dicatat dalam toolchain manifest/lockfile sebelum feature code. Tidak ada klaim bahwa versi patch terbaru telah dipasang. Drift menyediakan [transaksi lokal](https://drift.simonbinder.eu/dart_api/transactions/); transaksi remote tetap berbeda dan membutuhkan protocol ACK.

## Urutan delivery dan batas modul

Tidak ada tenggat kalender atau estimasi biaya yang disetujui. Task mengikuti dependensi; satu task satu unit review, umumnya maksimal lima file handwritten. Scaffolding/DTO generated tidak dihitung sebagai lima file manual, dan diff generated tetap direview. Jika sebuah task melebihi satu sesi, pecah berdasarkan output/interface sebelum mulai; ID coverage induk tetap dipertahankan.

| Hasil yang dapat didemokan kelak | Task | Bukti selesai |
|---|---|---|
| Lingkungan lokal dan kontrak | T01–T07 | Versi/lock/metadata nyata, schema/validator/receipt diuji |
| API pencatatan yang konsisten | T08–T15 | Login/scope/stock/create/revision/bootstrap, rollback dan retry |
| Slice operator pertama | T16–T23 | Login → kandang assigned → catatan offline → relaunch → sync sekali → history accepted |
| Pengelolaan farm | T24–T29 | Farm/kandang/kelompok/tim/pakan berizin dan versioned |
| Tugas, temuan, foto | T30–T36 | SOP literal, hasil offline, tindak lanjut, foto terpisah dari teks |
| Inbox, ringkasan, laporan | T37–T40 | Push optional, null/missing, CSV snapshot accepted |
| Kesiapan rilis dan pilot | T41–T46 | Native, security, restore, load, release dan farm/UAT nyata |

Prioritaskan demo slice T23 sebelum memperluas layar pengelola. T11 dapat berjalan independen dari T10 setelah T09; T24/T30/T32 setelah dependensinya juga independen. Urutan topologis lengkap ada di tiap task. Ini identifikasi independensi, bukan instruksi menjalankan agent paralel sekarang.

## Struktur file dan tanggung jawab

`backend/app/<Module>` berisi layanan/policy bisnis; `Http/Controllers` hanya boundary DTO/actor/key/status; `Support` transaction/error/receipt/counter. Migrations mengikuti contracts/schema.json; jangan menaruh seluruh bisnis dalam controller. `mobile/lib/features/<module>` berisi screen+view model; `core` API, encryption, outbox, cache, session. Generated wire DTO berada di `backend/app/Contracts/Dto` dan `mobile/lib/core/api/generated`, tidak diedit manual. Widget menerima view model; view model memanggil repository/API facade, bukan SQL widget.

Modify entries pada task menunjuk blok route/config yang baru dibuat T02; gunakan simbol/operationId sebagai anchor karena line number pada file yang belum ada belum dapat diketahui. File yang sudah ada (`CI`, scripts, user-guide) dipertahankan kecuali perubahan gate yang dinyatakan. Map lengkap per task ada di bagian bawah dan `contracts/plan.json`.

## Kontrak fixtures dan shared types

`JsonObject = Map<String,Object?>` pada Dart, `array<string,mixed>` pada PHP. UUID adalah string UUIDv4, tanggal bisnis `YYYY-MM-DD`, timestamp UTC RFC3339. `ActorScope(actorId,farmId,role,cageIds)` internal; generated `Ack` tepat dari kontrak. Generated DTO mempunyai factory `fromArray/toArray` PHP dan `fromJson/toJson` Dart; generator menolak unknown fields, tipe, enum dan required/null yang tidak cocok dengan OpenAPI. `ResourceQuery=array<string,mixed>` memakai nama parameter kontrak, bukan filter bebas yang diteruskan ke SQL.

Test fixture T03 harus menyediakan helper berikut, digunakan cuplikan task: `Scenario::layerFarm():array`, `secondOwnerRow(User):array`, `dailyRow(array):array`, `receipt(array):array`, `admin(array):User`, `flockUpdate(array,array):array`, `memberUpdate(array,array):array`, `adjustment(array,string,string):array`, `acceptDaily(array):DailyRecord`, `dailyRevision(array,int):array`, `revise(array,DailyRecord,int):Ack`, `failAt(string):void`, `scope(User):ActorScope`, `today(array):string`, `bootstrap(User):SyncPage`, `bootstrapNext(User,SyncPage):SyncPage`, `containsResource(SyncPage,string):bool`, `deltaContains(User,SyncPage,string):bool`, `weeklyTemplate(array):TaskTemplate`, `closedIncident(array):Incident`, `action(Incident):array`, `acceptedPhoto(array):Attachment`, `incidentEvent(array):NotificationEvent`, `failFcm():void`, `acceptedDailyIntent(array):array`, `ageOperationalRows(int):void`, `replayIntent(TestCase,array,array):TestResponse`. Fixture bodies create database rows/services/HTTP requests, bukan hard-coded hasil PASS. Failure injection hanya test binding, tidak endpoint publik. Keys `daily`/`incident` memuat semua required fields dari OpenAPI; dates diturunkan injectable clock/farm. Password contoh hanya `.env.example`/test ephemeral, tidak secret nyata.

`makeMobileScenario():Future<MobileScenario>` menyediakan `appAt(String,{JsonObject? args}):Widget`, real encrypted test Drift storage dan securestore fake terisolasi; `enqueueDaily/enqueueIncident/enqueueIncidentWithPhoto/relaunch/loginAsB/loginAsOperator():Future<void>`, `pendingIds/acceptedScopeIds():Future<List<String>>`, `encryptAsA(String):Future<Uint8List>`, `decryptCurrent(Uint8List):Future<String>`, `incidentText():Future<String>`, `worker:SyncWorker`, `photoWorker:PhotoWorker`, `bootstrap:BootstrapCoordinator`, fake `transport` yang bisa menolak, memutus ACK setelah efek server, dan mencatat keys/body/effects. `PartitionMismatch` adalah exception saat AAD/partition tidak cocok. `Intent.daily/taskResult/incident/incidentAction/onlineMaster` factory menghasilkan immutable payload; resourceid/key dibuat sekali. `PhotoState`, `FormState`, `InboxState` enum di view model, `RetryDecision` di retry_policy.dart. `targets.requireAccess(kind,id)` wrapper ApiClient.get operation sesuai resource. `parents.isAccepted(id)` membaca accepted cache; uploader.send memakai uploadAttachment. Helper test tidak dibundel release.

Cuplikan di task adalah titik perilaku yang harus dibangun dan diuji, bukan aplikasi lengkap yang sudah dikompilasi. Impor/types/DTO generated dan glue route mengikuti kontrak bagian ini. Laravel service methods list/get/create/update yang diringkas pada task mempunyai bentuk umum `list(ActorScope,array $query):array`, `get(ActorScope,string $id):<Resource>`, `create(ActorScope,<Input> $input,string $key):Ack`, `update(ActorScope,string $id,<Update> $input,string $key):Ack`; nama spesifik operasi tetap dari OpenAPI. Signature ambigu atau perubahan wire contract harus diselesaikan dalam amendment, bukan tebakan executor.

## Siklus kerja setiap task kelak

Semua checkbox masih kosong. Test command pada dokumen ini merupakan rencana verifikasi, bukan evidence PASS. First-run FAIL harus berasal dari perilaku yang belum ada; apabila task prasyarat/fixture belum siap, selesaikan dependensi dulu. Green berarti semua kasus pada Acceptance dan AC terkait lulus, bukan satu cuplikan saja. Jalankan PostgreSQL integration untuk invariant backend; jangan menggantinya dengan mock/SQLite. Setelah focused tests PASS, lint/contract/drift/secret staged gate lalu commit file task dan perubahan spec/kontrak terkait bersama. Pure refactor mencatat `spec: no change — reason`.

Device ID pada native command diganti dari `flutter devices`; test local tidak memerlukan farm nyata. Backup/deployment/signing menggunakan environment dan credentials yang disediakan saat eksekusi, tidak disimpan di repo. Task manual mencatat evidence observasi; tidak mengklaim tes native/restore hanya dari shell snippet.

### T01 — Kesiapan metadata dan versi terkunci

**Dependencies:** Tidak ada; permintaan eksekusi baru diperlukan.

**Acceptance:** AC-42. Catat patch yang benar-benar tersedia, lisensi/dependency dan checksum; jangan menebak versi atau digest. Pilih lingkungan kerja dengan metadata Git writable, pertahankan seluruh dokumen. Kegagalan Git/SDK menghalangi T02.

**Files:**

- Create: `toolchain/manifest.json`
- Create: `toolchain/flutter-version.txt`
- Create: `docs/evidence/toolchain.md`

**Interfaces:**

- Consumes: Keluarga versi pada docs/architecture.md dan SDK archive resmi Flutter; tidak ada app.
- Produces: Manifest berisi versi Flutter/Dart/PHP/Composer/PostgreSQL, checksum SDK, image digest; repository .git writable dan secret hooks aktif.

- [ ] **1. Periksa prasyarat dan tulis check/evidence berikut.**

```bash
git rev-parse --is-inside-work-tree
flutter --version --machine
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `flutter --version --machine; php --version; composer --version; git rev-parse --is-inside-work-tree; python3 scripts/check_secrets.py`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Selesaikan prasyarat/prosedur dan rekam evidence nyata.**

```bash
git config core.hooksPath .githooks
flutter --version --machine > docs/evidence/flutter-version.json
python3 -c 'import json,pathlib; v=json.load(open("docs/evidence/flutter-version.json")); pathlib.Path("toolchain/flutter-version.txt").write_text(v["frameworkVersion"]+"\n")'
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `flutter --version --machine; php --version; composer --version; git rev-parse --is-inside-work-tree; python3 scripts/check_secrets.py`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add toolchain/manifest.json toolchain/flutter-version.txt docs/evidence/toolchain.md
git commit -m "feat: t01 ternava kesiapan metadata dan versi terkunci"
```

### T02 — Aplikasi lokal dan health probes

**Dependencies:** T01

**Acceptance:** AC-42, AC-45. flutter create mobile, Laravel scaffold backend, pasang Sanctum dan queue database dengan lockfiles. Docker port API hanya 127.0.0.1:8080; Postgres tidak expose host. Worker/scheduler terpisah. /api/v1 untuk bisnis, health di root.

**Files:**

- Create: `compose.yaml`
- Create: `backend/Dockerfile`
- Modify: `backend/routes/api.php`
- Create: `backend/app/Http/Controllers/HealthController.php`
- Create: `backend/tests/Feature/HealthTest.php`

**Interfaces:**

- Consumes: toolchain/manifest.json; Laravel 13/PHP 8.4/PostgreSQL 18; scaffold framework generated.
- Produces: GET /health/live tanpa DB; GET /health/ready memeriksa DB/schema/private storage; service api/worker/scheduler memakai satu image.

**Operation IDs:** `liveness`, `readiness`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_liveness_does_not_need_database(): void {
    $this->getJson('/health/live')->assertOk()->assertJsonPath('data.status', 'ok');
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose config --quiet; docker compose run --rm api php artisan test --filter=HealthTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
public function live(): JsonResponse {
    return response()->json(['data' => ['status' => 'ok', 'checked_at' => now()->toISOString()]]);
}
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose config --quiet; docker compose run --rm api php artisan test --filter=HealthTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add compose.yaml backend/Dockerfile backend/routes/api.php backend/app/Http/Controllers/HealthController.php backend/tests/Feature/HealthTest.php
git commit -m "feat: t02 ternava aplikasi lokal dan health probes"
```

### T03 — Batas kontrak dan fixtures integrasi

**Dependencies:** T02

**Acceptance:** AC-32, AC-36, AC-41, AC-42. Validator penuh OpenAPI 3.1 dan JSON Schema 2020-12; tool Python dipin sesudah kompatibilitas diperiksa. DTO generated hanya wire data, snake_case dipertahankan di JSON; null tetap null. Scenario menggunakan factory nyata, 100 ayam, saldo pakan 300.00 kg, operator assigned dan tanggal relatif waktu farm.

**Files:**

- Create: `scripts/validate_openapi.py`
- Create: `scripts/generate_dto.py`
- Create: `backend/tests/Support/Scenario.php`
- Create: `backend/tests/Feature/ContractTest.php`
- Create: `mobile/test/support/scenario.dart`

**Interfaces:**

- Consumes: contracts/openapi.json, examples.json, schema.json; fixture PostgreSQL memakai schema terpisah per worker.
- Produces: PHP generated App\Contracts\Dto\<Schema>::fromArray(array $data): self dan toArray(): array; Dart generated <Schema>.fromJson(JsonObject json), toJson(): JsonObject. Scenario::layerFarm(): array{owner:User,operator:User,other:User,cage:Cage,flock:Flock,feed:FeedType,daily:array,incident:array}. Future<MobileScenario> makeMobileScenario() dengan real Drift, fake transport controllable, injectable clock/storage fault.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_wire_quantity_rejects_float(): void {
    $f = Scenario::layerFarm();
    $this->actingAs($f['operator'])->postJson('/api/v1/daily-records',
        [...$f['daily'], 'feed_kg' => 12.5])->assertStatus(422);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `python3 scripts/validate_openapi.py; python3 scripts/generate_dto.py --check; docker compose run --rm api php artisan test --filter=ContractTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
function requireKg(mixed $value): string {
    if (!is_string($value) || !preg_match('/^(0|[1-9][0-9]{0,11})\.[0-9]{2}$/D', $value)) {
        throw ValidationException::withMessages(['feed_kg' => ['Gunakan kg dengan dua angka desimal.']]);
    }
    return $value;
}
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `python3 scripts/validate_openapi.py; python3 scripts/generate_dto.py --check; docker compose run --rm api php artisan test --filter=ContractTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add scripts/validate_openapi.py scripts/generate_dto.py backend/tests/Support/Scenario.php backend/tests/Feature/ContractTest.php mobile/test/support/scenario.dart
git commit -m "feat: t03 ternava batas kontrak dan fixtures integrasi"
```

### T04 — Schema akses dan sync counter

**Dependencies:** T03

**Acceptance:** AC-08, AC-27, AC-33, AC-35, AC-36, AC-46. lower(username) unik, satu owner aktif per farm, receipt namespace farm/actor/key unik. Counter farm satu row, versi monotonic; soft deletion/pseudonymization menjaga referensi dan dedup. FK cage_assignments diaktifkan sesudah tabel cages pada T05.

**Files:**

- Create: `backend/database/migrations/2026_10_01_000001_access.php`
- Create: `backend/database/migrations/2026_10_01_000002_sync.php`
- Create: `backend/tests/Feature/AccessSchemaTest.php`

**Interfaces:**

- Consumes: contracts/schema.json: farms/users/memberships/device_sessions/cage_assignments/idempotency_receipts/sync_changes/sync_counters/audit_events.
- Produces: Migrasi semua tabel di daftar, composite farm FK bila relevan; device_sessions merupakan metadata token Sanctum.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_only_one_active_owner_per_farm(): void {
    $f = Scenario::layerFarm();
    $this->expectException(QueryException::class);
    DB::table('memberships')->insert(Scenario::secondOwnerRow($f['owner']));
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=AccessSchemaTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
DB::statement("CREATE UNIQUE INDEX one_active_owner ON memberships (farm_id) WHERE role = 'owner' AND active = true");
DB::statement('CREATE UNIQUE INDEX username_folded ON users (lower(username))');
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=AccessSchemaTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/database/migrations/2026_10_01_000001_access.php backend/database/migrations/2026_10_01_000002_sync.php backend/tests/Feature/AccessSchemaTest.php
git commit -m "feat: t04 ternava schema akses dan sync counter"
```

### T05 — Schema kandang, kelompok, stok

**Dependencies:** T04

**Acceptance:** AC-04, AC-06, AC-15, AC-16, AC-30, AC-31. Case-fold cage/feed/flock code unik dalam farm; opening sekali/feedtype; active flock satu/cage; stok >=0. Tanggal overlap dan prefix populasi juga dijaga service/lock; test PostgreSQL, bukan SQLite backend.

**Files:**

- Create: `backend/database/migrations/2026_10_01_000003_flocks_feed.php`
- Create: `backend/tests/Feature/FlockFeedSchemaTest.php`

**Interfaces:**

- Consumes: contracts/schema.json: cages/flocks/feed_types/feed_balances/feed_entries/population_entries; access schema T04.
- Produces: DECIMAL(14,2) kg, DECIMAL(18,2) IDR, farm FK/index/partial uniqueness; migrations framework tidak dihitung dalam 26 tabel logis.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_negative_balance_is_rejected_by_database(): void {
    $f = Scenario::layerFarm();
    $this->expectException(QueryException::class);
    DB::table('feed_balances')->where('feed_type_id', $f['feed']->id)->update(['quantity_kg' => '-0.01']);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=FlockFeedSchemaTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
DB::statement('ALTER TABLE feed_balances ADD CONSTRAINT balance_nonnegative CHECK (quantity_kg >= 0)');
DB::statement("CREATE UNIQUE INDEX one_active_flock ON flocks(cage_id) WHERE status = 'active'");
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=FlockFeedSchemaTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/database/migrations/2026_10_01_000003_flocks_feed.php backend/tests/Feature/FlockFeedSchemaTest.php
git commit -m "feat: t05 ternava schema kandang kelompok stok"
```

### T06 — Schema operasional, foto dan event

**Dependencies:** T05

**Acceptance:** AC-11, AC-20, AC-26, AC-28, AC-37, AC-38. Snapshot/revision/version dan indeks filter mengikuti schema; task/incident hasil tidak menimpa histori. notification_outbox merupakan event bisnis, queue Laravel merupakan pengiriman framework terpisah.

**Files:**

- Create: `backend/database/migrations/2026_10_01_000004_operations.php`
- Create: `backend/database/migrations/2026_10_01_000005_delivery.php`
- Create: `backend/tests/Feature/OperationsSchemaTest.php`

**Interfaces:**

- Consumes: contracts/schema.json: daily_records/daily_revisions/task_templates/task_runs/task_results/incidents/incident_actions/attachments/inbox_items/push_devices/notification_outbox.
- Produces: Daily unique farm+flock+date, taskrun unique template+date, inbox unique event+user; private file metadata.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_daily_total_is_unique(): void {
    $f = Scenario::layerFarm();
    DB::table('daily_records')->insert(Scenario::dailyRow($f));
    $this->expectException(QueryException::class);
    DB::table('daily_records')->insert(Scenario::dailyRow($f));
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=OperationsSchemaTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
DB::statement('CREATE UNIQUE INDEX one_daily_total ON daily_records(farm_id, flock_id, business_date)');
DB::statement('CREATE UNIQUE INDEX one_inbox_delivery ON inbox_items(event_id, user_id)');
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=OperationsSchemaTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/database/migrations/2026_10_01_000004_operations.php backend/database/migrations/2026_10_01_000005_delivery.php backend/tests/Feature/OperationsSchemaTest.php
git commit -m "feat: t06 ternava schema operasional foto dan event"
```

### T07 — Mutation executor: auth, receipt dan urutan commit

**Dependencies:** T06

**Acceptance:** AC-26, AC-27, AC-36. Authorize sebelum lookup/replay. DB transaction mengunci sync_counter farm dulu, kemudian flock UUID, resource, feedbalance UUID, receipt; deadlock max3 ->503. Hash method+canonical path+canonical JSON; replay hash beda ->409; reject tidak membuat receipt. ACK hanya sesudah transaction commit.

**Files:**

- Create: `backend/app/Support/ActorScope.php`
- Create: `backend/app/Support/CanonicalJson.php`
- Create: `backend/app/Support/MutationExecutor.php`
- Create: `backend/app/Support/ChangeWriter.php`
- Create: `backend/tests/Feature/MutationExecutorTest.php`

**Interfaces:**

- Consumes: ActorScope readonly(actorId:string,farmId:string,role:string,cageIds:array); generated Ack; schema T04–06.
- Produces: MutationExecutor::run(ActorScope $actor,string $key,string $method,string $path,array $payload,Closure $authorize,Closure $write): Ack. ChangeWriter::append(ActorScope $actor,string $kind,string $id,int $version,array $data): int; CanonicalJson::encode(array $value): string.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_replay_has_one_effect_and_original_ack(): void {
    $f = Scenario::layerFarm(); $key = (string) Str::uuid();
    $first = $this->actingAs($f['owner'])->withHeader('Idempotency-Key', $key)->postJson('/api/v1/feed-entries', Scenario::receipt($f));
    $again = $this->withHeader('Idempotency-Key', $key)->postJson('/api/v1/feed-entries', Scenario::receipt($f));
    $again->assertExactJson($first->json()); $this->assertDatabaseCount('idempotency_receipts', 1);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=MutationExecutorTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
function canonicalize(mixed $v): mixed {
    if (!is_array($v)) return $v;
    if (!array_is_list($v)) ksort($v, SORT_STRING);
    return array_map('canonicalize', $v);
}
$hash = hash('sha256', $method.'\n'.$path.'\n'.json_encode(canonicalize($payload), JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES));
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=MutationExecutorTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Support/ActorScope.php backend/app/Support/CanonicalJson.php backend/app/Support/MutationExecutor.php backend/app/Support/ChangeWriter.php backend/tests/Feature/MutationExecutorTest.php
git commit -m "feat: t07 ternava mutation executor auth receipt dan urutan commit"
```

### T08 — Login, password change dan sesi perangkat

**Dependencies:** T07

**Acceptance:** AC-01, AC-24, AC-35, AC-36, AC-41. Token expires7hari; tidak ada refresh OAuth. First-change hanya session/change/logout; change/reset revoke semua token dan login kembali. Lease24jam diterbitkan hanya setelah validasi online. Password never log/cache/receipt plaintext; login limiter per username+IP dan IP.

**Files:**

- Create: `backend/app/FarmAccess/SessionService.php`
- Create: `backend/app/Http/Controllers/SessionController.php`
- Create: `backend/app/Http/Middleware/RequirePasswordChange.php`
- Modify: `backend/routes/api.php`
- Create: `backend/tests/Feature/SessionTest.php`

**Interfaces:**

- Consumes: Sanctum token metadata; LoginInput/PasswordInput/Session/SessionInfo; ActorScope dari membership aktif.
- Produces: SessionService::login(LoginInput $input): Session; session(User $user): SessionInfo; changePassword(User $user,PasswordInput $input): void; logout(User $user,string $tokenId): void.

**Operation IDs:** `login`, `session`, `changePassword`, `logout`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_first_login_requires_password_change(): void {
    $f = Scenario::layerFarm(); $f['operator']->update(['password_change_required' => true]);
    $this->actingAs($f['operator'])->getJson('/api/v1/cages')->assertStatus(403)->assertJsonPath('error.code','PASSWORD_CHANGE_REQUIRED');
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=SessionTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
$token = $user->createToken($deviceName, ['*'], now()->addDays(7));
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=SessionTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/FarmAccess/SessionService.php backend/app/Http/Controllers/SessionController.php backend/app/Http/Middleware/RequirePasswordChange.php backend/routes/api.php backend/tests/Feature/SessionTest.php
git commit -m "feat: t08 ternava login password change dan sesi perangkat"
```

### T09 — Farm dan kandang berizin

**Dependencies:** T08

**Acceptance:** AC-02, AC-03, AC-04, AC-36. Operator hanya assignment aktif; missing/out-of-scope ->404. Zona farm immutable sesudah operasi/jadwal pertama. Code case-fold conflict tidak overwrite. Semua response mengikuti wrappers kontrak dan as_of server.

**Files:**

- Create: `backend/app/FarmAccess/FarmService.php`
- Create: `backend/app/Flocks/CageService.php`
- Create: `backend/app/Http/Controllers/FarmController.php`
- Create: `backend/app/Http/Controllers/CageController.php`
- Create: `backend/tests/Feature/FarmCageTest.php`

**Interfaces:**

- Consumes: ActorScope; MutationExecutor; FarmInput/CageInput/CageUpdate; timezone IANA dan opaque keyset Query.
- Produces: FarmService::get(ActorScope $actor): Farm; update(ActorScope $actor,FarmInput $input,string $key): Ack. CageService::list(ActorScope $actor,array $query): array; get(ActorScope $actor,string $id): Cage; create/update menerima DTO matching operation dan mengembalikan Ack.

**Operation IDs:** `getFarm`, `updateFarm`, `listCage`, `createCage`, `getCage`, `updateCage`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_operator_does_not_see_other_cage(): void {
    $f = Scenario::layerFarm(); $hidden = Cage::factory()->create(['farm_id'=>$f['owner']->farm_id]);
    $this->actingAs($f['operator'])->getJson('/api/v1/cages')->assertOk()->assertJsonMissing(['id'=>$hidden->id]);
    $this->getJson('/api/v1/cages/'.$hidden->id)->assertNotFound();
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=FarmCageTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
$query = Cage::query()->where('farm_id', $actor->farmId);
if ($actor->role === 'operator') $query->whereIn('id', $actor->cageIds);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=FarmCageTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/FarmAccess/FarmService.php backend/app/Flocks/CageService.php backend/app/Http/Controllers/FarmController.php backend/app/Http/Controllers/CageController.php backend/tests/Feature/FarmCageTest.php
git commit -m "feat: t09 ternava farm dan kandang berizin"
```

### T10 — Kelompok dan rentang populasi

**Dependencies:** T09

**Acceptance:** AC-05, AC-06, AC-31. Inclusive overlap ditolak dalam lock kandang/flock; kelompok aktif atau selesai difilter. Finished tanpa tanggal ->tanggal farm saat ini dengan konfirmasi UI. Sesudah operasi, initial population/placed/cage immutable; edit lain alasan+base_version. Semua prefix populasi berdasarkan tanggal nonnegatif.

**Files:**

- Create: `backend/app/Flocks/FlockService.php`
- Create: `backend/app/Flocks/PopulationProjection.php`
- Create: `backend/app/Http/Controllers/FlockController.php`
- Create: `backend/tests/Feature/FlockTest.php`

**Interfaces:**

- Consumes: ActorScope; MutationExecutor; FlockInput/FlockUpdate; population_entries dan date farm.
- Produces: FlockService::list(ActorScope $actor,array $query): array; get(ActorScope $actor,string $id): Flock; create(ActorScope $actor,FlockInput $input,string $key): Ack; update(ActorScope $actor,string $id,FlockUpdate $input,string $key): Ack. PopulationProjection::assertPrefixes(string $flockId,array $replacement): void.

**Operation IDs:** `listFlock`, `createFlock`, `getFlock`, `updateFlock`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_initial_population_cannot_change_after_daily(): void {
    $f=Scenario::layerFarm(); Scenario::acceptDaily($f);
    $this->actingAs($f['owner'])->withHeader('Idempotency-Key',(string)Str::uuid())->patchJson('/api/v1/flocks/'.$f['flock']->id, Scenario::flockUpdate($f,['initial_population'=>101]))->assertStatus(422);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=FlockTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
$population = $initial;
foreach ($orderedEvents as $event) {
    $population += $event->incoming - $event->outgoing - ($event->mortality ?? 0);
    if ($population < 0) throw ValidationException::withMessages(['population_change'=>['Populasi pada suatu tanggal akan negatif.']]);
}
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=FlockTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Flocks/FlockService.php backend/app/Flocks/PopulationProjection.php backend/app/Http/Controllers/FlockController.php backend/tests/Feature/FlockTest.php
git commit -m "feat: t10 ternava kelompok dan rentang populasi"
```

### T11 — Akun dan assignment farm

**Dependencies:** T09

**Acceptance:** AC-07, AC-08, AC-24, AC-36. Admin hanya mengelola operator; owner pertama dilindungi. Temporary password min12, edit tidak membawa password; hash sebelum database. Assignment hanya kandang farm; revoke/reset memutus sesi/push aktif; scopeVersion berubah untuk bootstrap reset.

**Files:**

- Create: `backend/app/FarmAccess/MemberService.php`
- Create: `backend/app/FarmAccess/MemberPolicy.php`
- Create: `backend/app/Http/Controllers/MemberController.php`
- Create: `backend/tests/Feature/MemberTest.php`

**Interfaces:**

- Consumes: ActorScope; MutationExecutor; MemberInput/MemberUpdate/ResetPasswordInput; lease/session T08.
- Produces: MemberService::list/get sesuai DTO; create(ActorScope $actor,MemberInput $input,string $key): Ack; update(ActorScope $actor,string $id,MemberUpdate $input,string $key): Ack; resetPassword(ActorScope $actor,string $id,ResetPasswordInput $input): void.

**Operation IDs:** `listMember`, `createMember`, `getMember`, `updateMember`, `resetMemberPassword`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_admin_cannot_promote_operator_to_admin(): void {
    $f=Scenario::layerFarm(); $admin=Scenario::admin($f);
    $this->actingAs($admin)->withHeader('Idempotency-Key',(string)Str::uuid())->patchJson('/api/v1/members/'.$f['operator']->membership_id,Scenario::memberUpdate($f,['role'=>'admin']))->assertForbidden();
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=MemberTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
if ($actor->role === 'admin' && ($target->role !== 'operator' || $requestedRole !== 'operator')) abort(403);
if ($target->role === 'owner') abort(403);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=MemberTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/FarmAccess/MemberService.php backend/app/FarmAccess/MemberPolicy.php backend/app/Http/Controllers/MemberController.php backend/tests/Feature/MemberTest.php
git commit -m "feat: t11 ternava akun dan assignment farm"
```

### T12 — Referensi pakan dan ledger immutable

**Dependencies:** T10, T11

**Acceptance:** AC-15, AC-16, AC-17, AC-30. Opening sekali dan sebelum pemakaian; receipt kg/harga>0+pemasok; adjustment kg>0+reason tanpa harga/pemasok. Operator boleh referensi/saldo, tidak ledger pembelian. SQL decimal atau integer-string arithmetic; saldo tidak negatif/overflow, zero daily tidak membuat entry penggunaan.

**Files:**

- Create: `backend/app/Feed/FeedService.php`
- Create: `backend/app/Feed/FeedProjection.php`
- Create: `backend/app/Http/Controllers/FeedController.php`
- Create: `backend/tests/Feature/FeedTest.php`

**Interfaces:**

- Consumes: ActorScope; MutationExecutor; FeedTypeInput/FeedTypeUpdate/FeedEntryInput; kg string fixed2.
- Produces: FeedService::createType/updateType/createEntry menerima ActorScope, DTO matching operation, key:string dan return Ack; listTypes/getType/listBalances/listEntries -> matching DTO/wrapper. FeedProjection::apply(string $feedTypeId,string $signedKg,string $sourceKind,string $sourceId,int $version): void.

**Operation IDs:** `listFeedType`, `createFeedType`, `getFeedType`, `updateFeedType`, `listBalances`, `listEntries`, `createEntry`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_adjustment_cannot_make_negative_stock(): void {
    $f=Scenario::layerFarm();
    $this->actingAs($f['owner'])->withHeader('Idempotency-Key',(string)Str::uuid())->postJson('/api/v1/feed-entries',Scenario::adjustment($f,'out','300.01'))->assertStatus(422)->assertJsonPath('error.code','INSUFFICIENT_STOCK');
    $this->assertDatabaseHas('feed_balances',['feed_type_id'=>$f['feed']->id,'quantity_kg'=>'300.00']);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=FeedTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
$affected=DB::update('UPDATE feed_balances SET quantity_kg=quantity_kg+CAST(? AS numeric) WHERE feed_type_id=? AND quantity_kg+CAST(? AS numeric) BETWEEN 0 AND 999999999999.99',[$signedKg,$feedTypeId,$signedKg]);
if ($affected !== 1) throw new DomainFailure('INSUFFICIENT_STOCK',422);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=FeedTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Feed/FeedService.php backend/app/Feed/FeedProjection.php backend/app/Http/Controllers/FeedController.php backend/tests/Feature/FeedTest.php
git commit -m "feat: t12 ternava referensi pakan dan ledger immutable"
```

### T13 — Create harian atomik

**Dependencies:** T12

**Acceptance:** AC-13, AC-26, AC-27, AC-28, AC-30, AC-31, AC-32. Satu full total farm/flock/date; unique lain ->DAILY_ALREADY_EXISTS. Date tidak future, max30hari dan dalam flock; valid referensi meski feed0. Daily/version/feed/population/audit/receipt/change/event satu transaction. null mortalitas tidak dianggap pemeriksaan sehat.

**Files:**

- Create: `backend/app/Daily/CreateDaily.php`
- Create: `backend/app/Daily/DailyPolicy.php`
- Create: `backend/app/Http/Controllers/DailyController.php`
- Create: `backend/tests/Feature/CreateDailyTest.php`

**Interfaces:**

- Consumes: MutationExecutor::run; FeedProjection::apply; PopulationProjection::assertPrefixes; generated DailyInput/Ack.
- Produces: CreateDaily::handle(ActorScope $actor,DailyInput $input,string $key): Ack; DailyController list/get sesuai OpenAPI. DomainFailure readonly(code:string,status:int,fields:array=[],currentVersion:?int=null).

**Operation IDs:** `listDaily`, `createDaily`, `getDaily`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_fault_rolls_back_every_business_effect(): void {
    $f=Scenario::layerFarm(); Scenario::failAt('after_feed_entry');
    $this->actingAs($f['operator'])->withHeader('Idempotency-Key',(string)Str::uuid())->postJson('/api/v1/daily-records',$f['daily'])->assertStatus(500);
    $this->assertDatabaseCount('daily_records',0); $this->assertDatabaseCount('idempotency_receipts',0);
    $this->assertDatabaseHas('feed_balances',['feed_type_id'=>$f['feed']->id,'quantity_kg'=>'300.00']);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=CreateDailyTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
$row = DailyRecord::create($input->toArray()+['farm_id'=>$actor->farmId,'version'=>1]);
if ($input->feed_kg !== '0.00') $feeds->apply($input->feed_type_id,'-'.$input->feed_kg,'daily',$row->id,1);
$population->assertPrefixes($input->flock_id,[$row->business_date=>$input->toArray()]);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=CreateDailyTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Daily/CreateDaily.php backend/app/Daily/DailyPolicy.php backend/app/Http/Controllers/DailyController.php backend/tests/Feature/CreateDailyTest.php
git commit -m "feat: t13 ternava create harian atomik"
```

### T14 — Revisi harian dengan kompensasi ledger

**Dependencies:** T13

**Acceptance:** AC-29, AC-30, AC-31, AC-32. Owner/admin saja; baseversion compare, reason wajib, flock/date tidak pindah. Lock dua feed UUID order, reverse lama+apply baru immutable, null preservation, prefix historical valid, seluruh efek rollback bila gagal. Versi 2 tidak menimpa snapshot v1.

**Files:**

- Create: `backend/app/Daily/ReviseDaily.php`
- Create: `backend/app/Http/Controllers/DailyRevisionController.php`
- Create: `backend/tests/Feature/ReviseDailyTest.php`

**Interfaces:**

- Consumes: MutationExecutor; FeedProjection; PopulationProjection; DailyRevisionInput full replacement; generated Ack.
- Produces: ReviseDaily::handle(ActorScope $actor,string $dailyId,DailyRevisionInput $input,string $key): Ack; controller listDailyRevisions ->DailyRevisionPage.

**Operation IDs:** `reviseDaily`, `listDailyRevisions`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_stale_revision_changes_nothing(): void {
    $f=Scenario::layerFarm(); $daily=Scenario::acceptDaily($f); Scenario::revise($f,$daily,1);
    $this->actingAs($f['owner'])->withHeader('Idempotency-Key',(string)Str::uuid())->postJson('/api/v1/daily-records/'.$daily->id.'/revisions',Scenario::dailyRevision($f,1))->assertStatus(409)->assertJsonPath('error.current_version',2);
    $this->assertDatabaseCount('daily_revisions',1);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=ReviseDailyTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
if ($row->version !== $input->base_version) throw new DomainFailure('VERSION_CONFLICT',409,[], $row->version);
if ($row->feed_kg !== '0.00') $feeds->apply($row->feed_type_id,$row->feed_kg,'daily_reversal',$row->id,$row->version+1);
if ($input->feed_kg !== '0.00') $feeds->apply($input->feed_type_id,'-'.$input->feed_kg,'daily',$row->id,$row->version+1);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=ReviseDailyTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Daily/ReviseDaily.php backend/app/Http/Controllers/DailyRevisionController.php backend/tests/Feature/ReviseDailyTest.php
git commit -m "feat: t14 ternava revisi harian dengan kompensasi ledger"
```

### T15 — Bootstrap dan delta ber-watermark

**Dependencies:** T14

**Acceptance:** AC-33, AC-34, AC-36. Fixed snapshot watermark, scope/asof, lease15menit, delta dariwatermark sama. Tidak mempage live rows seolah snapshot: versioned change payload/asof reconstruction. Delta30hari; cursor expired/scopechange ->CURSOR_RESET_REQUIRED. Inbox ownuser; feedbalance idfeedtype.

**Files:**

- Create: `backend/app/Sync/SyncService.php`
- Create: `backend/app/Sync/CursorCodec.php`
- Create: `backend/app/Http/Controllers/SyncController.php`
- Create: `backend/tests/Feature/SyncTest.php`

**Interfaces:**

- Consumes: ChangeWriter commit-ordered seq; ActorScope dan scopeVersion; SyncPage, cursor opaque/signature.
- Produces: SyncService::bootstrap(ActorScope $actor,?string $cursor): SyncPage; changes(ActorScope $actor,?string $cursor): SyncPage; CursorCodec::encode(array $claims): string; decode(string $cursor): array.

**Operation IDs:** `bootstrapSync`, `pullChanges`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_bootstrap_pages_exclude_newer_writes(): void {
    $f=Scenario::layerFarm(); $page=Scenario::bootstrap($f['operator']);
    $later=Scenario::acceptDaily($f); $rest=Scenario::bootstrapNext($f['operator'],$page);
    $this->assertFalse(Scenario::containsResource($rest,$later->id));
    $this->assertTrue(Scenario::deltaContains($f['operator'],$page,$later->id));
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=SyncTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
$claims=['farm_id'=>$actor->farmId,'actor_id'=>$actor->actorId,'scope_version'=>$scopeVersion,'high_watermark'=>$counter->value,'expires_at'=>now()->addMinutes(15)->timestamp];
$changes=DB::table('sync_changes')->where('farm_id',$actor->farmId)->where('sequence','<=',$claims['high_watermark']);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=SyncTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Sync/SyncService.php backend/app/Sync/CursorCodec.php backend/app/Http/Controllers/SyncController.php backend/tests/Feature/SyncTest.php
git commit -m "feat: t15 ternava bootstrap dan delta ber-watermark"
```

### T16 — Client HTTP typed dan kuantitas presisi

**Dependencies:** T03, T15

**Acceptance:** AC-23, AC-32, AC-42. Timeout20detik, endpoint resolver dari operationId, Idempotency-Key dan auth header. Field integer/null tidak float. Replay tidak membuat UUID baru; error uniform tidak stacktrace. Jangan retry blind otomatis POST di HTTP layer.

**Files:**

- Create: `mobile/lib/core/api/api_client.dart`
- Create: `mobile/lib/core/api/api_failure.dart`
- Create: `mobile/lib/core/quantity/kg.dart`
- Create: `mobile/test/core/api_quantity_test.dart`

**Interfaces:**

- Consumes: Generated DTO T03; typedef JsonObject=Map<String,Object?>; Ack.fromJson; canonical key UUID dari outbox.
- Produces: ApiClient.request(String operationId,{JsonObject? body,String? idempotencyKey}): Future<JsonObject>; ApiFailure(code,status,fields,retryable,currentVersion,retryAfter); Kg.parse(String text), wire():String, units:BigInt.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
test('kg memakai integer presisi', () {
  expect(Kg.parse('12.50').units, BigInt.from(1250));
  expect(() => Kg.parse(''), throwsFormatException);
});
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/core/api_quantity_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
factory Kg.parse(String text) {
  if (!RegExp(r'^(0|[1-9][0-9]{0,11})\.[0-9]{2}$').hasMatch(text)) throw const FormatException('Isi kg dengan dua desimal.');
  return Kg._(BigInt.parse(text.replaceAll('.', '')));
}
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/core/api_quantity_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/core/api/api_client.dart mobile/lib/core/api/api_failure.dart mobile/lib/core/quantity/kg.dart mobile/test/core/api_quantity_test.dart
git commit -m "feat: t16 ternava client http typed dan kuantitas presisi"
```

### T17 — Store terenkripsi dan lease akun

**Dependencies:** T16

**Acceptance:** AC-24, AC-35, AC-37. AAD actor/farm/object/schema, random nonce setiapwrite; key perpartition tidak ada diSQLite/backup. Encrypt payload, cache, foto. Lease24jam; rollbackclock locks; logout/gantiidentity online+confirm, preservesqueue namun keylocked. Reboot/unknownmonotonic memerlukan validasi ulang bila rollback tidak bisa dibuktikan.

**Files:**

- Create: `mobile/lib/core/local/partition_store.dart`
- Create: `mobile/lib/core/local/payload_cipher.dart`
- Create: `mobile/lib/core/session/offline_lease.dart`
- Create: `mobile/test/core/partition_lease_test.dart`

**Interfaces:**

- Consumes: Drift tables pada contracts/schema.json local_store; cryptography AES256GCM + platform secure store; injectable Clock.
- Produces: PartitionId(actorId:String,farmId:String); PartitionStore.unlock(PartitionId id):Future<void>, lock():Future<void>, transaction<T>(Future<T> Function() action):Future<T>; PayloadCipher.encrypt/decrypt(Uint8List bytes,String aad):Future<Uint8List>; OfflineLease.canWrite(DateTime wall,Duration monotonic):bool.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
test('akun B gagal decrypt payload A', () async {
  final s=await makeMobileScenario(); final bytes=await s.encryptAsA('catatan');
  await s.loginAsB(); expect(() => s.decryptCurrent(bytes), throwsA(isA<PartitionMismatch>()));
});
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/core/partition_lease_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
final algorithm=AesGcm.with256bits();
final box=await algorithm.encrypt(bytes, secretKey:key, nonce:algorithm.newNonce(), aad:utf8.encode(aad));
return Uint8List.fromList(box.concatenation());
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/core/partition_lease_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/core/local/partition_store.dart mobile/lib/core/local/payload_cipher.dart mobile/lib/core/session/offline_lease.dart mobile/test/core/partition_lease_test.dart
git commit -m "feat: t17 ternava store terenkripsi dan lease akun"
```

### T18 — Outbox immutable dan pemulihan retry

**Dependencies:** T17

**Acceptance:** AC-12, AC-13, AC-19, AC-23, AC-27, AC-35. Persist draft+frozenpayload+stablekey transaction sebelum pending UI; fail disk preservesform. Single worker foreground depsorder, sendingrelaunch->pending. ACK localatomic clearsoutbox state onlyafterACK. 429RetryAfter, timeout/5xx jitter2s–5min max5/session,401/403stopblockedauth,409/422needsreview,manualretry noTTL.

**Files:**

- Create: `mobile/lib/core/sync/outbox_repository.dart`
- Create: `mobile/lib/core/sync/sync_worker.dart`
- Create: `mobile/lib/core/sync/retry_policy.dart`
- Create: `mobile/test/core/outbox_fault_test.dart`

**Interfaces:**

- Consumes: PartitionStore.transaction, ApiClient.request; typedef OperationId=String; Intent(operationId,resourceId,endpoint,payload,dependencies,state).
- Produces: OutboxRepository.enqueue(Intent intent):Future<void>; accept(OperationId id,Ack ack):Future<void>; recoverSending():Future<void>; SyncWorker.runOnce():Future<void>; RetryPolicy.next(ApiFailure failure,int attempt):RetryDecision.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
test('timeout sesudah server commit memakai key sama', () async {
  final s=await makeMobileScenario(); await s.enqueueDaily(); s.transport.dropNextAck();
  await s.worker.runOnce(); await s.relaunch(); await s.worker.runOnce();
  expect(s.transport.seenKeys.toSet(), hasLength(1)); expect(s.transport.businessEffects,1);
});
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/core/outbox_fault_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
await store.transaction(() async {
  await drafts.save(intent.resourceId, intent.payload);
  await outbox.insert(intent);
});
await outbox.recoverState(from:'sending',to:'pending');
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/core/outbox_fault_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/core/sync/outbox_repository.dart mobile/lib/core/sync/sync_worker.dart mobile/lib/core/sync/retry_policy.dart mobile/test/core/outbox_fault_test.dart
git commit -m "feat: t18 ternava outbox immutable dan pemulihan retry"
```

### T19 — Cache delta dan reset yang aman

**Dependencies:** T18

**Acceptance:** AC-10, AC-33, AC-34. Delta payload+cursor atomic; fault leavesoldcheckpoint. Reset reconstructacceptedcache atomically afterallbootstrap pages, preservesdraft+outbox. Scope revocation removesacceptedoutofscope, queueitemneedsreview; dates/as_of stayvisible. References seven-daytaskwindow tidak diasumsikan ada saatcacheempty.

**Files:**

- Create: `mobile/lib/core/sync/cache_repository.dart`
- Create: `mobile/lib/core/sync/bootstrap_coordinator.dart`
- Create: `mobile/test/core/cache_fault_test.dart`

**Interfaces:**

- Consumes: PartitionStore; ApiClient; SyncPage; SyncCheckpoint(cursor,scopeVersion,asOf).
- Produces: CacheRepository.applyPage(SyncPage page):Future<void>; replaceAcceptedSnapshot(List<SyncPage> pages):Future<void>; BootstrapCoordinator.refresh():Future<void>.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
test('reset mempertahankan intent pending', () async {
  final s=await makeMobileScenario(); await s.enqueueDaily();
  s.transport.requireCursorReset(); await s.bootstrap.refresh();
  expect(await s.pendingIds(), hasLength(1)); expect(await s.acceptedScopeIds(), isNot(contains(s.revokedCageId)));
});
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/core/cache_fault_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
await store.transaction(() async {
  for (final change in page.changes) { await acceptedCache.apply(change); }
  await checkpoints.save(page.nextCursor,page.scopeVersion,page.asOf);
});
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/core/cache_fault_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/core/sync/cache_repository.dart mobile/lib/core/sync/bootstrap_coordinator.dart mobile/test/core/cache_fault_test.dart
git commit -m "feat: t19 ternava cache delta dan reset yang aman"
```

### T20 — Design native, router dan back behavior

**Dependencies:** T19

**Acceptance:** AC-25, AC-39, AC-40. FiraSansfontbundledlicense;48dp target, textscale200%,320/414, statuslabel bukanwarnasaja, reducedmotion. Semua24routeguardrole/object, noAC900previewtoolbar; backdirtycancel/save. Nativecomponents standard bukan HTML embedded.

**Files:**

- Create: `mobile/lib/ui/theme/ternava_theme.dart`
- Create: `mobile/lib/ui/components/status_panel.dart`
- Create: `mobile/lib/ui/navigation/app_router.dart`
- Create: `mobile/lib/ui/navigation/role_shell.dart`
- Create: `mobile/test/ui/navigation_test.dart`

**Interfaces:**

- Consumes: DESIGN.md;24ids manifest; Session role; native Navigator routes, PopScope untukdirtyform.
- Produces: AppRouter.open(String screenId,{JsonObject? args}):Future<void>; StatusPanel(kind,label,asOf,onRetry); RoleShell(role,child).

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('back tidak membuang isian setelah batal', (tester) async {
  final s=await makeMobileScenario(); await tester.pumpWidget(s.appAt('daily-form'));
  await tester.enterText(find.byKey(const Key('feed-kg')),'12.50'); await tester.pageBack();
  await tester.tap(find.text('Tetap mengisi')); await tester.pumpAndSettle();
  expect(find.text('12.50'),findsOneWidget);
});
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/ui/navigation_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
final buttonStyle=FilledButton.styleFrom(minimumSize:const Size(48,48));
final primary=const Color(0xFF195647);
final duration=MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds:140);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/ui/navigation_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/ui/theme/ternava_theme.dart mobile/lib/ui/components/status_panel.dart mobile/lib/ui/navigation/app_router.dart mobile/lib/ui/navigation/role_shell.dart mobile/test/ui/navigation_test.dart
git commit -m "feat: t20 ternava design native router dan back behavior"
```

### T21 — Login dan akun

**Dependencies:** T20

**Acceptance:** AC-01, AC-24, AC-35, AC-39. Loginonlinebootstrapbaruworkspace; firstchangeinline loginstate, logoutpendingconfirm/cancel, sesiexpiredreauthpreservesqueue. Pushpermission optional. Janganpresetusername/password. Passwordfield tidakpersistence; logoutonline locks partition.

**Files:**

- Create: `mobile/lib/features/access/login_screen.dart`
- Create: `mobile/lib/features/access/login_view_model.dart`
- Create: `mobile/lib/features/access/account_screen.dart`
- Create: `mobile/lib/features/access/account_view_model.dart`
- Create: `mobile/test/features/t21_test.dart`

**Interfaces:**

- Consumes: ApiClient, BootstrapCoordinator, PartitionStore; LoginInput/PasswordInput; role/session responses.
- Produces: LoginViewModel.submit(LoginInput input):Future<void>; AccountViewModel.logout({required bool confirmed}):Future<void>; changePassword(PasswordInput input):Future<void>.

**Screens:** `login`, `account`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('login pertama offline memberi pemulihan', (t) async { final s=await makeMobileScenario(); s.transport.offline=true; await t.pumpWidget(s.appAt('login')); await t.tap(find.text('Masuk')); await t.pumpAndSettle(); expect(find.text('Sambungkan internet untuk masuk pertama kali.'),findsOneWidget); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t21_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
await api.request('login',body:input.toJson());
await bootstrap.refresh();
notifyListeners();
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t21_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/access/login_screen.dart mobile/lib/features/access/login_view_model.dart mobile/lib/features/access/account_screen.dart mobile/lib/features/access/account_view_model.dart mobile/test/features/t21_test.dart
git commit -m "feat: t21 ternava login dan akun"
```

### T22 — Hari ini dan formulir harian

**Dependencies:** T21

**Acceptance:** AC-10, AC-13, AC-32, AC-39. Hariini assignedcache+datedstatus; formblank, explicit0, nullmortality/notchecked, incomplete draftboleh. Sendcomplete freezesintent denganUUID; acceptedreadonly, revisionowneradminbaseversion+reason, diskfailuretidakhapusisian. Buka temuan darifinding bukanauto duplicate.

**Files:**

- Create: `mobile/lib/features/daily/today_screen.dart`
- Create: `mobile/lib/features/daily/today_view_model.dart`
- Create: `mobile/lib/features/daily/daily_form_screen.dart`
- Create: `mobile/lib/features/daily/daily_form_view_model.dart`
- Create: `mobile/test/features/t22_test.dart`

**Interfaces:**

- Consumes: CacheRepository, OutboxRepository; DailyInput/DailyRevisionInput; UUIDgeneratedresourceidonce.
- Produces: TodayViewModel.load():Future<void>; DailyFormViewModel.saveDraft():Future<void>, submit():Future<void>, revise():Future<void>.

**Screens:** `today`, `daily-form`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('pakan kosong tidak menjadi nol', (t) async { final s=await makeMobileScenario(); await t.pumpWidget(s.appAt('daily-form')); await t.tap(find.text('Kirim catatan')); await t.pump(); expect(await s.pendingIds(),isEmpty); expect(find.text('Isi jumlah pakan dalam kg.'),findsOneWidget); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t22_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
final wire=DailyInput.fromJson(values);
await outbox.enqueue(Intent.daily(wire,operationId:uuid.v4()));
state=FormState.pending; notifyListeners();
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t22_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/daily/today_screen.dart mobile/lib/features/daily/today_view_model.dart mobile/lib/features/daily/daily_form_screen.dart mobile/lib/features/daily/daily_form_view_model.dart mobile/test/features/t22_test.dart
git commit -m "feat: t22 ternava hari ini dan formulir harian"
```

### T23 — Riwayat dan pusat sinkronisasi

**Dependencies:** T22

**Acceptance:** AC-14, AC-23, AC-39. Historyfilterscage/date mergeslocal+accepted tanpaacceptedtotalscampurpending. Syncitemdetailkey/payloadtidakeditsilent, retryrespectsblockedauth/needsreview, canceldraftconfirmed. ACKreadresource/delta; importedAPIpageopaque.

**Files:**

- Create: `mobile/lib/features/daily/daily_history_screen.dart`
- Create: `mobile/lib/features/daily/daily_history_view_model.dart`
- Create: `mobile/lib/features/sync/sync_center_screen.dart`
- Create: `mobile/lib/features/sync/sync_center_view_model.dart`
- Create: `mobile/test/features/t23_test.dart`

**Interfaces:**

- Consumes: OutboxRepository,SyncWorker,CacheRepository; historyquery cageId/dateRange/status.
- Produces: DailyHistoryViewModel.filter(JsonObject query):Future<void>; SyncCenterViewModel.retry(String operationId):Future<void>, reauthenticate():Future<void>.

**Screens:** `daily-history`, `sync-center`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('422 menyimpan payload untuk ditinjau', (t) async { final s=await makeMobileScenario(); await s.enqueueDaily(); s.transport.rejectNext('INSUFFICIENT_STOCK',422); await s.worker.runOnce(); await t.pumpWidget(s.appAt('sync-center')); expect(find.text('Perlu ditinjau'),findsOneWidget); expect(await s.pendingIds(),hasLength(1)); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t23_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
if (item.state=='blocked_auth') { await router.open('login'); return; }
await worker.runOnce(); notifyListeners();
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t23_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/daily/daily_history_screen.dart mobile/lib/features/daily/daily_history_view_model.dart mobile/lib/features/sync/sync_center_screen.dart mobile/lib/features/sync/sync_center_view_model.dart mobile/test/features/t23_test.dart
git commit -m "feat: t23 ternava riwayat dan pusat sinkronisasi"
```

### T24 — Setup farm

**Dependencies:** T21

**Acceptance:** AC-02, AC-39. Farmnama/lokasi/zona tersimpan server; zonasetelahoperasiimmutable. Masteractions online denganpersistkey/payloadbilaresponseunknown; formawal bukanfiktifprefill. Setup route owner/admin.

**Files:**

- Create: `mobile/lib/features/access/farm_setup_screen.dart`
- Create: `mobile/lib/features/access/farm_setup_view_model.dart`
- Create: `mobile/test/features/t24_test.dart`

**Interfaces:**

- Consumes: ApiClient,OutboxRepository,SyncWorker; FarmInput/Farm.
- Produces: FarmSetupViewModel.save(FarmInput input):Future<void>.

**Screens:** `farm-setup`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('zona ditolak mempertahankan isian', (t) async { final s=await makeMobileScenario(); s.transport.rejectNext('VALIDATION_FAILED',422); await t.pumpWidget(s.appAt('farm-setup')); await t.enterText(find.byKey(const Key('farm-name')),'Farm Uji'); await t.tap(find.text('Simpan peternakan')); await t.pumpAndSettle(); expect(find.text('Farm Uji'),findsOneWidget); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t24_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
await outbox.enqueue(Intent.onlineMaster('updateFarm',input.toJson(),uuid.v4()));
await worker.runOnce();
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t24_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/access/farm_setup_screen.dart mobile/lib/features/access/farm_setup_view_model.dart mobile/test/features/t24_test.dart
git commit -m "feat: t24 ternava setup farm"
```

### T25 — Kandang dan form kandang

**Dependencies:** T24

**Acceptance:** AC-03, AC-04, AC-39. Assignedlist operator; owner/admincreateeditonline. Code/lokasi/keteranganfieldmatchesDTO; duplicateshowsfieldrecovery. Datedmissing/accepted/stale tidakindikatorproduksisehat.

**Files:**

- Create: `mobile/lib/features/flocks/cage_list_screen.dart`
- Create: `mobile/lib/features/flocks/cage_list_view_model.dart`
- Create: `mobile/lib/features/flocks/cage_form_screen.dart`
- Create: `mobile/lib/features/flocks/cage_form_view_model.dart`
- Create: `mobile/test/features/t25_test.dart`

**Interfaces:**

- Consumes: CacheRepository,ApiClient,OutboxRepository; CageInput/CageUpdate/Cage.
- Produces: CageListViewModel.load():Future<void>; CageFormViewModel.save(JsonObject input):Future<void>.

**Screens:** `cage-list`, `cage-form`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('kandang tersembunyi tidak muncul', (t) async { final s=await makeMobileScenario(); await s.loginAsOperator(); await t.pumpWidget(s.appAt('cage-list')); expect(find.text(s.revokedCageCode),findsNothing); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t25_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
items=await cache.listAssignedCages();
notifyListeners();
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t25_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/flocks/cage_list_screen.dart mobile/lib/features/flocks/cage_list_view_model.dart mobile/lib/features/flocks/cage_form_screen.dart mobile/lib/features/flocks/cage_form_view_model.dart mobile/test/features/t25_test.dart
git commit -m "feat: t25 ternava kandang dan form kandang"
```

### T26 — Kelompok aktif dan selesai

**Dependencies:** T25

**Acceptance:** AC-05, AC-06, AC-31, AC-39. Flockrange/statusfilters; AM02editreason, referensiawaldisabledafteroperations. finisheddateconfirm; invalid/overlaprecovery preservesform; recordhistoricaltidakcampurkelompokbaru.

**Files:**

- Create: `mobile/lib/features/flocks/flock_list_screen.dart`
- Create: `mobile/lib/features/flocks/flock_list_view_model.dart`
- Create: `mobile/lib/features/flocks/flock_form_screen.dart`
- Create: `mobile/lib/features/flocks/flock_form_view_model.dart`
- Create: `mobile/test/features/t26_test.dart`

**Interfaces:**

- Consumes: CacheRepository,OutboxRepository; FlockInput/FlockUpdate; acceptedresourceversion.
- Produces: FlockListViewModel.filter(String status):Future<void>; FlockFormViewModel.save():Future<void>.

**Screens:** `flock-list`, `flock-form`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('edit kelompok mencatat alasan', (t) async { final s=await makeMobileScenario(); await t.pumpWidget(s.appAt('flock-form',args:{'edit':true})); expect(find.byKey(const Key('change-reason')),findsOneWidget); final field=t.widget<TextField>(find.byKey(const Key('initial-population'))); expect(field.enabled,isFalse); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t26_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
final payload=FlockUpdate.fromJson({...values,'base_version':version,'reason':reason});
await outbox.enqueue(Intent.onlineMaster('updateFlock',payload.toJson(),uuid.v4()));
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t26_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/flocks/flock_list_screen.dart mobile/lib/features/flocks/flock_list_view_model.dart mobile/lib/features/flocks/flock_form_screen.dart mobile/lib/features/flocks/flock_form_view_model.dart mobile/test/features/t26_test.dart
git commit -m "feat: t26 ternava kelompok aktif dan selesai"
```

### T27 — Tim dan membuat akun

**Dependencies:** T25, T11

**Acceptance:** AC-07, AC-08, AC-24, AC-39. AM01createpasswordblank min12; editsandihidden; ownerprotected; adminrolechoiceoperatoronly. No publicsignup; assignmentselectionfarmonly. Password payload onlineexceptionnever persistedlocal; unknowncreate outcome resolvebyusername/serverstatus sebelum retrynewintent.

**Files:**

- Create: `mobile/lib/features/access/team_list_screen.dart`
- Create: `mobile/lib/features/access/team_list_view_model.dart`
- Create: `mobile/lib/features/access/member_form_screen.dart`
- Create: `mobile/lib/features/access/member_form_view_model.dart`
- Create: `mobile/test/features/t27_test.dart`

**Interfaces:**

- Consumes: ApiClient,MemberInput/MemberUpdate; backendidemreceiptmusthashsecretbutnotstoreplaintext.
- Produces: TeamListViewModel.load():Future<void>; MemberFormViewModel.create(MemberInput input):Future<void>, update(MemberUpdate input):Future<void>.

**Screens:** `team-list`, `member-form`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('password sementara tidak diprefill', (t) async { final s=await makeMobileScenario(); await t.pumpWidget(s.appAt('member-form')); expect(t.widget<TextField>(find.byKey(const Key('temporary-password'))).controller!.text,isEmpty); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t27_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
try { await api.request('createMember',body:input.toJson(),idempotencyKey:creationKey); }
finally { passwordController.clear(); }
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t27_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/access/team_list_screen.dart mobile/lib/features/access/team_list_view_model.dart mobile/lib/features/access/member_form_screen.dart mobile/lib/features/access/member_form_view_model.dart mobile/test/features/t27_test.dart
git commit -m "feat: t27 ternava tim dan membuat akun"
```

### T28 — Saldo dan transaksi pakan

**Dependencies:** T26, T12

**Acceptance:** AC-15, AC-16, AC-30, AC-39. Saldoaccepted+asof+originledger, offlinecachedreadonly. Receiptopeningadjustmentjenisfielddifferent, nosecondusageform; transientonlinekeypreservedforunknownresponse exceptsensitivepassword. Serverrejectnegative preservesform.

**Files:**

- Create: `mobile/lib/features/feed/feed_stock_screen.dart`
- Create: `mobile/lib/features/feed/feed_stock_view_model.dart`
- Create: `mobile/lib/features/feed/feed_entry_screen.dart`
- Create: `mobile/lib/features/feed/feed_entry_view_model.dart`
- Create: `mobile/test/features/t28_test.dart`

**Interfaces:**

- Consumes: ApiClient,CacheRepository,OutboxRepository; FeedEntryInput/FeedBalance/FeedEntry.
- Produces: FeedStockViewModel.load():Future<void>; FeedEntryViewModel.save(FeedEntryInput input):Future<void>.

**Screens:** `feed-stock`, `feed-entry`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('stok stale menampilkan waktu snapshot', (t) async { final s=await makeMobileScenario(); s.transport.offline=true; await t.pumpWidget(s.appAt('feed-stock')); expect(find.textContaining('Terakhir diperbarui'),findsOneWidget); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t28_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
final payload=FeedEntryInput.fromJson(values);
await outbox.enqueue(Intent.onlineMaster('createEntry',payload.toJson(),uuid.v4()));
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t28_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/feed/feed_stock_screen.dart mobile/lib/features/feed/feed_stock_view_model.dart mobile/lib/features/feed/feed_entry_screen.dart mobile/lib/features/feed/feed_entry_view_model.dart mobile/test/features/t28_test.dart
git commit -m "feat: t28 ternava saldo dan transaksi pakan"
```

### T29 — Jenis pakan dan ambang minimum

**Dependencies:** T28

**Acceptance:** AC-17, AC-39. Inactivejenis tetapreferensihistori; minthreshold kgpresisi, reason/version padaedit; stocks alerttransition bukanrefresh. Noautomatic purchasingrecommendations.

**Files:**

- Create: `mobile/lib/features/feed/feed_type_form_screen.dart`
- Create: `mobile/lib/features/feed/feed_type_form_view_model.dart`
- Create: `mobile/test/features/t29_test.dart`

**Interfaces:**

- Consumes: OutboxRepository,FeedTypeInput/FeedTypeUpdate; FeedStockViewModel navigation.
- Produces: FeedTypeFormViewModel.save(JsonObject input):Future<void>.

**Screens:** `feed-type-form`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('edit jenis memakai versi accepted', (t) async { final s=await makeMobileScenario(); await t.pumpWidget(s.appAt('feed-type-form',args:{'edit':true})); await t.tap(find.text('Simpan jenis pakan')); await t.pumpAndSettle(); expect(s.transport.lastBody['base_version'],1); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t29_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
await outbox.enqueue(Intent.onlineMaster('updateFeedType',input.toJson(),uuid.v4()));
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t29_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/feed/feed_type_form_screen.dart mobile/lib/features/feed/feed_type_form_view_model.dart mobile/test/features/t29_test.dart
git commit -m "feat: t29 ternava jenis pakan dan ambang minimum"
```

### T30 — Tugas SOP, scheduler dan hasil versi

**Dependencies:** T14, T11

**Acceptance:** AC-10, AC-11, AC-12, AC-27, AC-36. once/daily/weekly seven-daywindow; checklist literalmax20stableitemidsnapshot; rununique template/date. Canceled/stale reassignment ->409; hasilnote tidakcompleted, checkbox false tidakauto menjadi true. Tidakgenerated diagnosis/vaccine dosage.

**Files:**

- Create: `backend/app/Tasks/TaskService.php`
- Create: `backend/app/Tasks/MaterializeRuns.php`
- Create: `backend/app/Http/Controllers/TaskController.php`
- Create: `backend/tests/Feature/TaskTest.php`

**Interfaces:**

- Consumes: MutationExecutor; TaskTemplateInput/TaskTemplateUpdate/TaskResultInput; assignedcage; farmtimezone.
- Produces: TaskService::createTemplate/updateTemplate/result menerima ActorScope+matchingDTO+key ->Ack; list/get sesuai routes. MaterializeRuns::handle(string $farmId,DateTimeImmutable $start): int.

**Operation IDs:** `listTaskTemplate`, `createTaskTemplate`, `getTaskTemplate`, `updateTaskTemplate`, `listTaskRuns`, `getTaskRun`, `createTaskResult`, `listTaskResults`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_scheduler_twice_has_one_occurrence(): void {
    $f=Scenario::layerFarm(); Scenario::weeklyTemplate($f);
    app(MaterializeRuns::class)->handle($f['owner']->farm_id,new DateTimeImmutable('today'));
    app(MaterializeRuns::class)->handle($f['owner']->farm_id,new DateTimeImmutable('today'));
    $this->assertDatabaseCount('task_runs',1);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=TaskTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
TaskRun::firstOrCreate(['template_id'=>$template->id,'business_date'=>$date],['checklist_snapshot'=>$template->checklist,'assignee_id'=>$template->assignee_id,'version'=>1]);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=TaskTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Tasks/TaskService.php backend/app/Tasks/MaterializeRuns.php backend/app/Http/Controllers/TaskController.php backend/tests/Feature/TaskTest.php
git commit -m "feat: t30 ternava tugas sop scheduler dan hasil versi"
```

### T31 — Tugas dan hasil operator

**Dependencies:** T30, T22

**Acceptance:** AC-11, AC-12, AC-39. Templateonline; operatorresultofflinepersist, note/completedpisah, SOPcheckboxliteral. Hariini taskcache7days, canceledrunneedsreview. Batchsubmit checkbox tidaktoggleothers; acceptedread-onlyhistory.

**Files:**

- Create: `mobile/lib/features/tasks/task_form_screen.dart`
- Create: `mobile/lib/features/tasks/task_form_view_model.dart`
- Create: `mobile/lib/features/tasks/task_detail_screen.dart`
- Create: `mobile/lib/features/tasks/task_detail_view_model.dart`
- Create: `mobile/test/features/t31_test.dart`

**Interfaces:**

- Consumes: CacheRepository,OutboxRepository; TaskTemplateInput/TaskResultInput/TaskRun.
- Produces: TaskFormViewModel.save():Future<void>; TaskDetailViewModel.submit(TaskResultInput input):Future<void>.

**Screens:** `task-form`, `task-detail`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('menandai satu SOP tidak melengkapi semua', (t) async { final s=await makeMobileScenario(); await t.pumpWidget(s.appAt('task-detail')); await t.tap(find.byKey(const Key('check-item-1'))); await t.pump(); expect(t.widget<Checkbox>(find.byKey(const Key('check-item-2'))).value,isFalse); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t31_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
final payload=TaskResultInput.fromJson({...values,'base_version':run.version});
await outbox.enqueue(Intent.taskResult(run.id,payload,uuid.v4()));
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t31_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/tasks/task_form_screen.dart mobile/lib/features/tasks/task_form_view_model.dart mobile/lib/features/tasks/task_detail_screen.dart mobile/lib/features/tasks/task_detail_view_model.dart mobile/test/features/t31_test.dart
git commit -m "feat: t31 ternava tugas dan hasil operator"
```

### T32 — Temuan, assignment dan histori tindakan

**Dependencies:** T14, T11

**Acceptance:** AC-18, AC-19, AC-20, AC-27, AC-36. Open->in_progress->closed; close noteswajib; closedimmutable. Operatorassigned atau MA actions; observationmanualno medicalrecommendation. Textaccept tidakdependentfoto; source_dailyrecordhanya validacceptedobject dalamfarm.

**Files:**

- Create: `backend/app/Incidents/IncidentService.php`
- Create: `backend/app/Incidents/IncidentPolicy.php`
- Create: `backend/app/Http/Controllers/IncidentController.php`
- Create: `backend/tests/Feature/IncidentTest.php`

**Interfaces:**

- Consumes: ActorScope,MutationExecutor; IncidentInput/IncidentAssignmentInput/IncidentActionInput.
- Produces: IncidentService::create/assign/action menerimaActorScope+matchingDTO+key ->Ack; list/get/listActions ->matchingwrapper; versionsbasecompare.

**Operation IDs:** `listIncidents`, `createIncident`, `getIncident`, `assignIncident`, `createIncidentAction`, `listIncidentActions`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_closed_incident_cannot_be_changed(): void {
    $f=Scenario::layerFarm(); $incident=Scenario::closedIncident($f);
    $this->actingAs($f['owner'])->withHeader('Idempotency-Key',(string)Str::uuid())->postJson('/api/v1/incidents/'.$incident->id.'/actions',Scenario::action($incident))->assertStatus(409);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=IncidentTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
if ($incident->status==='closed') throw new DomainFailure('VERSION_CONFLICT',409,[],$incident->version);
if ($input->status==='closed' && trim($input->notes ?? '')==='') throw ValidationException::withMessages(['notes'=>['Jelaskan tindakan sebelum menutup temuan.']]);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=IncidentTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Incidents/IncidentService.php backend/app/Incidents/IncidentPolicy.php backend/app/Http/Controllers/IncidentController.php backend/tests/Feature/IncidentTest.php
git commit -m "feat: t32 ternava temuan assignment dan histori tindakan"
```

### T33 — Daftar dan catatan temuan

**Dependencies:** T32, T23

**Acceptance:** AC-18, AC-19, AC-39. Filterscope/status/assignment; textdraftoffline tahanrelaunch; optionalphoto statusseparate; timestampobservationUTCwithfarmdisplay. Observefindingnotautosaysdisease; newformblank, damagedphoto error actionable.

**Files:**

- Create: `mobile/lib/features/incidents/incident_list_screen.dart`
- Create: `mobile/lib/features/incidents/incident_list_view_model.dart`
- Create: `mobile/lib/features/incidents/incident_form_screen.dart`
- Create: `mobile/lib/features/incidents/incident_form_view_model.dart`
- Create: `mobile/test/features/t33_test.dart`

**Interfaces:**

- Consumes: OutboxRepository,CacheRepository; IncidentInput,photoqueueparentdependency.
- Produces: IncidentListViewModel.filter(JsonObject query):Future<void>; IncidentFormViewModel.saveDraft():Future<void>, submit():Future<void>.

**Screens:** `incident-list`, `incident-form`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('teks temuan tetap ada setelah upload gagal', (t) async { final s=await makeMobileScenario(); await s.enqueueIncident('Nafsu makan menurun'); await s.relaunch(); s.transport.failPhotos=true; await s.worker.runOnce(); expect(await s.incidentText(),'Nafsu makan menurun'); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t33_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
await outbox.enqueue(Intent.incident(input,uuid.v4()));
photoState=PhotoState.waitingForParent; notifyListeners();
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t33_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/incidents/incident_list_screen.dart mobile/lib/features/incidents/incident_list_view_model.dart mobile/lib/features/incidents/incident_form_screen.dart mobile/lib/features/incidents/incident_form_view_model.dart mobile/test/features/t33_test.dart
git commit -m "feat: t33 ternava daftar dan catatan temuan"
```

### T34 — Detail dan tindakan temuan

**Dependencies:** T33

**Acceptance:** AC-20, AC-22, AC-39. Role/assignedactionbuttons; versionconflict reloadpreservesnotes; closedreadonly; closewithnotes; inaccessibledeeplinkrecoverybacktoinbox/list. Actionhistoryactor+timestamp.

**Files:**

- Create: `mobile/lib/features/incidents/incident_detail_screen.dart`
- Create: `mobile/lib/features/incidents/incident_detail_view_model.dart`
- Create: `mobile/test/features/t34_test.dart`

**Interfaces:**

- Consumes: OutboxRepository,ApiClient; Incident/IncidentActionInput/IncidentAssignmentInput.
- Produces: IncidentDetailViewModel.assign(IncidentAssignmentInput input):Future<void>, act(IncidentActionInput input):Future<void>.

**Screens:** `incident-detail`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('close tanpa catatan ditolak', (t) async { final s=await makeMobileScenario(); await t.pumpWidget(s.appAt('incident-detail')); await t.tap(find.text('Tutup temuan')); await t.pump(); expect(find.text('Jelaskan tindakan sebelum menutup temuan.'),findsOneWidget); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t34_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
await outbox.enqueue(Intent.incidentAction(incident.id,input,uuid.v4()));
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t34_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/incidents/incident_detail_screen.dart mobile/lib/features/incidents/incident_detail_view_model.dart mobile/test/features/t34_test.dart
git commit -m "feat: t34 ternava detail dan tindakan temuan"
```

### T35 — Foto privat sesudah parent ACK

**Dependencies:** T32

**Acceptance:** AC-19, AC-36, AC-37. JPEG/PNG realdecode<=2MiB,max3parent lock; hash originalbytes beforeEXIFstrip, private storageACL everydownload. RejectfakeMIME/corrupt/decompressionoversize; stagingfile cleanup aftertransactionfailure. Filecommitcrash reconciler orphan cleanup; textneverrollback.

**Files:**

- Create: `backend/app/Attachments/AttachmentService.php`
- Create: `backend/app/Attachments/PhotoSanitizer.php`
- Create: `backend/app/Http/Controllers/AttachmentController.php`
- Create: `backend/tests/Feature/AttachmentTest.php`

**Interfaces:**

- Consumes: ActorScope,MutationExecutor; AttachmentInput multipart+rawbyteshash; accepted daily/incident parent.
- Produces: AttachmentService::upload(ActorScope $actor,AttachmentInput $input,string $key,UploadedFile $file): Ack; list(ActorScope $actor,array $query):array; download(ActorScope $actor,string $id):BinaryFileResponse; PhotoSanitizer::sanitize(UploadedFile $file):string.

**Operation IDs:** `uploadAttachment`, `listAttachments`, `downloadAttachment`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_cross_farm_photo_download_is_private(): void {
    $f=Scenario::layerFarm(); $photo=Scenario::acceptedPhoto($f);
    $this->actingAs($f['other'])->get('/api/v1/attachments/'.$photo->id.'/download')->assertNotFound();
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=AttachmentTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
if ($file->getSize()>2*1024*1024) throw ValidationException::withMessages(['file'=>['Foto maksimal 2 MiB.']]);
if (!in_array($file->getMimeType(),['image/jpeg','image/png'],true)) throw ValidationException::withMessages(['file'=>['Gunakan JPEG atau PNG yang dapat dibuka.']]);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=AttachmentTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Attachments/AttachmentService.php backend/app/Attachments/PhotoSanitizer.php backend/app/Http/Controllers/AttachmentController.php backend/tests/Feature/AttachmentTest.php
git commit -m "feat: t35 ternava foto privat sesudah parent ack"
```

### T36 — Antrean foto terenkripsi di perangkat

**Dependencies:** T35, T33

**Acceptance:** AC-19, AC-23, AC-37. Enqueueencryptpersistbeforestatus; max3/MIMEsize local dan server. Parent acceptedfirst, failedimage keepsrecovery/status, stablekey/hashbytesretry; permission/cameradenied formtextnotlost. Relogin correctpartitionunlock.

**Files:**

- Create: `mobile/lib/core/attachments/photo_repository.dart`
- Create: `mobile/lib/core/attachments/photo_worker.dart`
- Create: `mobile/test/core/photo_fault_test.dart`

**Interfaces:**

- Consumes: PayloadCipher,PartitionStore,OutboxRepository; parentAck, originalhash,validatedfilemetadata.
- Produces: PhotoRepository.add(String parentKind,String parentId,Uint8List bytes):Future<String>; PhotoWorker.runOnce():Future<void>.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
test('upload tidak berjalan sebelum parent ACK', () async { final s=await makeMobileScenario(); await s.enqueueIncidentWithPhoto(); await s.photoWorker.runOnce(); expect(s.transport.uploadCount,0); await s.worker.runOnce(); await s.photoWorker.runOnce(); expect(s.transport.uploadCount,1); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/core/photo_fault_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
if (!await parents.isAccepted(photo.parentId)) return;
final bytes=await cipher.decrypt(photo.encryptedBytes,photo.aad);
await uploader.send(photo.operationId,photo.sha256,bytes);
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/core/photo_fault_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/core/attachments/photo_repository.dart mobile/lib/core/attachments/photo_worker.dart mobile/test/core/photo_fault_test.dart
git commit -m "feat: t36 ternava antrean foto terenkripsi di perangkat"
```

### T37 — Inbox durable, event worker dan push optional

**Dependencies:** T32, T35

**Acceptance:** AC-17, AC-22, AC-38, AC-45. Inboxpersistfirst; FCMgenericIDpayloadnophysicalobservations. Stockthresholdonlycrossingdedup; retrymax5<=15min, tokeninvaliddeactivate, failuredoesnotrollbackinbox/business. Pushpermissiondenied normalstate; workerheartbeat.

**Files:**

- Create: `backend/app/Notifications/DeliverEvent.php`
- Create: `backend/app/Notifications/PushService.php`
- Create: `backend/app/Http/Controllers/InboxController.php`
- Create: `backend/app/Http/Controllers/PushController.php`
- Create: `backend/tests/Feature/NotificationTest.php`

**Interfaces:**

- Consumes: notification_outbox,inboxuniqueevent/user; ActorScope; PushDeviceInput; workerDBqueue.
- Produces: DeliverEvent::handle(string $eventId):void; PushService::send(string $userId,string $eventId):void; inboxlist/read and pushregister/unregister matchingwireDTO.

**Operation IDs:** `listInbox`, `readInbox`, `registerPush`, `unregisterPush`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_push_failure_keeps_one_inbox_item(): void {
    $f=Scenario::layerFarm(); $event=Scenario::incidentEvent($f); Scenario::failFcm();
    app(DeliverEvent::class)->handle($event->id); app(DeliverEvent::class)->handle($event->id);
    $this->assertDatabaseCount('inbox_items',1);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=NotificationTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
InboxItem::firstOrCreate(['event_id'=>$event->id,'user_id'=>$recipient->id],['resource_kind'=>$event->kind,'resource_id'=>$event->resource_id]);
SendPush::dispatch($recipient->id,$event->id)->afterCommit();
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=NotificationTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Notifications/DeliverEvent.php backend/app/Notifications/PushService.php backend/app/Http/Controllers/InboxController.php backend/app/Http/Controllers/PushController.php backend/tests/Feature/NotificationTest.php
git commit -m "feat: t37 ternava inbox durable event worker dan push optional"
```

### T38 — Ringkasan accepted dan laporan CSV

**Dependencies:** T37

**Acceptance:** AC-09, AC-14, AC-21, AC-32, AC-36, AC-41. MAreports only; max183hari; expectedflockdates termasuk historicalfinished. Pendingtidakdihitung, missingnull/zeroacceptedbeda, allmissingtotalnull; repeatablereadsnapshotasof. CSV UTF8 RFC4180 quote+formulaescaped, timezoneexplicit; no profitFCRclaim.

**Files:**

- Create: `backend/app/Insights/ReportService.php`
- Create: `backend/app/Insights/CsvWriter.php`
- Create: `backend/app/Http/Controllers/InsightsController.php`
- Create: `backend/tests/Feature/ReportTest.php`

**Interfaces:**

- Consumes: ActorScope,acceptedDBsnapshot; Dashboard/Report; activeflockdaterangehistorical; farmtimezone.
- Produces: ReportService::dashboard(ActorScope $actor):Dashboard; operations(ActorScope $actor,string $from,string $to):Report; CsvWriter::write(Report $report,resource $stream):void.

**Operation IDs:** `dashboard`, `operationsReport`, `exportOperationsReport`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_missing_is_not_zero_in_report(): void {
    $f=Scenario::layerFarm(); $r=app(ReportService::class)->operations(Scenario::scope($f['owner']),Scenario::today($f),Scenario::today($f));
    $this->assertNull($r->eggs_count); $this->assertSame(0,$r->accepted_count);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=ReportTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
function csvCell(string $value): string {
    return preg_match('/^[\s]*[=+@-]/u',$value) ? "'".$value : $value;
}
fputcsv($stream,array_map('csvCell',$cells),',','"','');
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=ReportTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Insights/ReportService.php backend/app/Insights/CsvWriter.php backend/app/Http/Controllers/InsightsController.php backend/tests/Feature/ReportTest.php
git commit -m "feat: t38 ternava ringkasan accepted dan laporan csv"
```

### T39 — Dashboard pemilik dan laporan

**Dependencies:** T38, T29

**Acceptance:** AC-09, AC-21, AC-32, AC-39. Statuskelengkapan/date first; attentionlinksACL, accepted/stalesnapshot/asof. Reportperiodvalidation183hari, exportloading/failure preservesfilters, formulaescapedserverfile. Cachedsnapshotoffline jelas, missingtidakrender0.

**Files:**

- Create: `mobile/lib/features/insights/home_screen.dart`
- Create: `mobile/lib/features/insights/home_view_model.dart`
- Create: `mobile/lib/features/insights/reports_screen.dart`
- Create: `mobile/lib/features/insights/reports_view_model.dart`
- Create: `mobile/test/features/t39_test.dart`

**Interfaces:**

- Consumes: ApiClient,CacheRepository; Dashboard/Report.
- Produces: HomeViewModel.refresh():Future<void>; ReportsViewModel.load(String from,String to):Future<void>, exportCsv():Future<void>.

**Screens:** `home`, `reports`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('report missing tidak menampilkan nol', (t) async { final s=await makeMobileScenario(); s.transport.reportAllMissing=true; await t.pumpWidget(s.appAt('reports')); await t.pumpAndSettle(); expect(find.text('Belum dicatat'),findsWidgets); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t39_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
final text=report.eggsCount==null ? 'Belum dicatat' : '${report.eggsCount} butir';
notifyListeners();
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t39_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/insights/home_screen.dart mobile/lib/features/insights/home_view_model.dart mobile/lib/features/insights/reports_screen.dart mobile/lib/features/insights/reports_view_model.dart mobile/test/features/t39_test.dart
git commit -m "feat: t39 ternava dashboard pemilik dan laporan"
```

### T40 — Inbox dan pembukaan link berizin

**Dependencies:** T39, T34, T37

**Acceptance:** AC-22, AC-24, AC-38, AC-39. Inboxownuser unread/readidempotent, allowedtargetresolvedserver beforeopen; deleted/revokedtargetshowsbackrecovery, FCMdisabledinboxworks. Deep linksrouteids only, noarbitraryURLfetch.

**Files:**

- Create: `mobile/lib/features/insights/inbox_screen.dart`
- Create: `mobile/lib/features/insights/inbox_view_model.dart`
- Create: `mobile/test/features/t40_test.dart`

**Interfaces:**

- Consumes: ApiClient,AppRouter,CacheRepository; Inbox; pushregistrationsettingonAccount.
- Produces: InboxViewModel.load():Future<void>, open(String itemId):Future<void>, markRead(String itemId):Future<void>.

**Screens:** `inbox`.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('link dicabut memberi jalan kembali', (t) async { final s=await makeMobileScenario(); s.transport.revokeInboxTarget=true; await t.pumpWidget(s.appAt('inbox')); await t.tap(find.byKey(const Key('inbox-item-1'))); await t.pumpAndSettle(); expect(find.text('Kembali ke pemberitahuan'),findsOneWidget); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/features/t40_test.dart`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
try { await targets.requireAccess(item.kind,item.resourceId); await router.open(item.screenId,args:{'id':item.resourceId}); }
on ApiFailure catch(e) { if(e.status==404 || e.status==403) state=InboxState.targetUnavailable; else rethrow; }
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/features/t40_test.dart`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/lib/features/insights/inbox_screen.dart mobile/lib/features/insights/inbox_view_model.dart mobile/test/features/t40_test.dart
git commit -m "feat: t40 ternava inbox dan pembukaan link berizin"
```

### T41 — Abuse limits, retensi dan deletion journal

**Dependencies:** T40

**Acceptance:** AC-36, AC-41, AC-46. Login5/minusernameIP+30/minIP/auth120/upload10/export3; JSON64KiB/query5s/tx10s/DB30max50. Business730d/photos180/inbox90/delta30/log14/backup30; ledgerconsistent archive ratherthanreferentialbreak. Receiptactivefarmminimaldedup retained; closefarmexport/pseudonymization+journalreapplyonrestore. No remote URLfetch API.

**Files:**

- Create: `backend/app/Http/Middleware/RequestLimits.php`
- Create: `backend/app/Console/Commands/ApplyRetention.php`
- Create: `backend/app/Console/Commands/CloseFarm.php`
- Create: `backend/tests/Feature/HardeningRetentionTest.php`
- Create: `docs/runbook/retention.md`

**Interfaces:**

- Consumes: operations-security.md limits/retention; everyrouteserverACL; receiptminimalhashACKtombstone.
- Produces: ApplyRetention::handle():int; CloseFarm::handle():int; RequestLimits::handle(Request $request,Closure $next):Response.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```php
public function test_old_receipt_still_blocks_duplicate_after_retention(): void {
    $f=Scenario::layerFarm(); $intent=Scenario::acceptedDailyIntent($f); Scenario::ageOperationalRows(731);
    $this->artisan('ternava:retention')->assertExitCode(0);
    Scenario::replayIntent($this,$f,$intent)->assertOk(); $this->assertDatabaseCount('idempotency_receipts',1);
}
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=HardeningRetentionTest`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```php
RateLimiter::for('uploads',fn(Request $r)=>Limit::perMinute(10)->by($r->user()->id));
RateLimiter::for('exports',fn(Request $r)=>Limit::perMinute(3)->by($r->user()->id));
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=HardeningRetentionTest`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add backend/app/Http/Middleware/RequestLimits.php backend/app/Console/Commands/ApplyRetention.php backend/app/Console/Commands/CloseFarm.php backend/tests/Feature/HardeningRetentionTest.php docs/runbook/retention.md
git commit -m "feat: t41 ternava abuse limits retensi dan deletion journal"
```

### T42 — Uji native seluruh state dan flow offline

**Dependencies:** T41, T36, T31

**Acceptance:** AC-01, AC-10, AC-12, AC-13, AC-19, AC-23, AC-24, AC-25, AC-33, AC-34, AC-35, AC-39, AC-40. 320/414dp text200%,48dp,reducedmotion,contrast4.5:1. Modepesawat/relaunch/storagefault/timeoutaftercommit/accountswitch/deniedpush/camera. Unit widgettidakmenggantikan TalkBackperangkat nyata. Userguide role/task/stock/sync recovery memakai realapplabels.

**Files:**

- Create: `mobile/integration_test/operator_flow_test.dart`
- Create: `mobile/integration_test/account_isolation_test.dart`
- Create: `mobile/test/ui/screen_states_test.dart`
- Create: `docs/evidence/android-uat.md`
- Modify: `docs/user-guide/README.md`

**Interfaces:**

- Consumes: 24screen/132state source manifest; compiledFlutter Android device; fakefixture builddebugseparatefromrelease.
- Produces: Evidence withdeviceOS/ABI/buildcommit/screenshots/AC/outcome; everymanifeststate recovery; nativeTalkBackmanualchecklist.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```dart
testWidgets('catatan offline survive relaunch', (t) async { final s=await makeMobileScenario(); await s.loginAsOperator(); s.transport.offline=true; await s.enqueueDaily(); await s.relaunch(); expect(await s.pendingIds(),hasLength(1)); s.transport.offline=false; await s.worker.runOnce(); expect(s.transport.businessEffects,1); });
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `cd mobile && flutter test test/ui/screen_states_test.dart; flutter test integration_test -d DEVICE_ID`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```dart
for(final screen in manifest.screens) {
  for(final state in screen.states) {
    await tester.pumpWidget(s.appAt(screen.id,args:{'state':state}));
    expect(tester.takeException(),isNull);
  }
}
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `cd mobile && flutter test test/ui/screen_states_test.dart; flutter test integration_test -d DEVICE_ID`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add mobile/integration_test/operator_flow_test.dart mobile/integration_test/account_isolation_test.dart mobile/test/ui/screen_states_test.dart docs/evidence/android-uat.md docs/user-guide/README.md
git commit -m "feat: t42 ternava uji native seluruh state dan flow offline"
```

### T43 — Backup, restore dan metrik gangguan

**Dependencies:** T41

**Acceptance:** AC-43, AC-45, AC-46. Dailybackupoffhost30d untukpilot,RPO24hRTO4h nyata diukur. Restore counts/FK/ledger/fileACL/logins. queueoldest5min/heartbeat3min/backup26h/disk80%/5xx5%5min alerts; FCMdegradedpisahdariAPI. SLO99.5%bulanan termasukmaintenance baru diukur sesudahservicejalan.

**Files:**

- Create: `ops/backup.sh`
- Create: `ops/restore.sh`
- Create: `ops/health-monitor.py`
- Create: `backend/app/Console/Commands/Heartbeat.php`
- Create: `docs/runbook/restore.md`

**Interfaces:**

- Consumes: Private uploads+Postgres+encryptionkeyssecuredseparately; deletionjournal; functionalprojectowner/farmadmincontacts dariAC47.
- Produces: Backup encrypted(snapshot+uploads+manifest+checksum); restore isolatedDB+privatefiles+reapplyjournal; worker/schedulerheartbeatJSON/metrics.

- [ ] **1. Periksa prasyarat dan tulis check/evidence berikut.**

```bash
bash ops/restore.sh --verify-isolated
# Expected: gagal tanpa manifest backup dan isolated database yang terkonfigurasi.
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `bash ops/backup.sh --dry-run; bash ops/restore.sh --verify-isolated; python3 ops/health-monitor.py --self-check`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Selesaikan prasyarat/prosedur dan rekam evidence nyata.**

```bash
pg_dump --format=custom --file "$BACKUP_DIR/database.dump" "$DATABASE_URL"
sha256sum "$BACKUP_DIR/database.dump" > "$BACKUP_DIR/checksums.txt"
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `bash ops/backup.sh --dry-run; bash ops/restore.sh --verify-isolated; python3 ops/health-monitor.py --self-check`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add ops/backup.sh ops/restore.sh ops/health-monitor.py backend/app/Console/Commands/Heartbeat.php docs/runbook/restore.md
git commit -m "feat: t43 ternava backup restore dan metrik gangguan"
```

### T44 — Concurrency dan benchmark kapasitas

**Dependencies:** T42, T43

**Acceptance:** AC-26, AC-27, AC-28, AC-29, AC-30, AC-31, AC-34, AC-44. 20identicalsamekey, twooperatorsdailydiffkeys, consumptions270+270against300, twoadminbasev1, twofeedtyperevision, bootstrapwritesinterleaved. Assertions seluruhledger/popu/event/receipts; latencyclaims harus dariHTTPbenchmark.

**Files:**

- Create: `ops/load/seed.php`
- Create: `ops/load/benchmark.js`
- Create: `backend/tests/Feature/ConcurrentMutationTest.php`
- Create: `docs/evidence/load.md`

**Interfaces:**

- Consumes: Postgresreal,HTTP20clients,2vCPU4GiBresourcecap; generated100kdailyfixtures, no productiondataset.
- Produces: Concurrencyevidence duplicateeffects0, transaction rollback atallfaultpoints; k6summary p95read500ms/write1s,error<1%,15min.

- [ ] **1. Tulis test perilaku berikut; tambah seluruh kasus Acceptance pada file test task.**

```javascript
export const options={vus:20,duration:'15m',thresholds:{'http_req_duration{kind:read}':['p(95)<500'],'http_req_duration{kind:write}':['p(95)<1000'],http_req_failed:['rate<0.01']}};
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `docker compose run --rm api php artisan test --filter=ConcurrentMutationTest; k6 run ops/load/benchmark.js`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Implementasikan boundary dan invariant yang dinyatakan; anchor perilaku berikut berada pada file produksi task.**

```javascript
const headers={'Authorization':`Bearer ${token}`,'Idempotency-Key':operationId,'Content-Type':'application/json'};
const res=http.post(`${base}/api/v1/daily-records`,JSON.stringify(payload),{headers,tags:{kind:'write'}});
check(res,{'accepted-or-original-ack':r=>r.status===200 || r.status===201});
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `docker compose run --rm api php artisan test --filter=ConcurrentMutationTest; k6 run ops/load/benchmark.js`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add ops/load/seed.php ops/load/benchmark.js backend/tests/Feature/ConcurrentMutationTest.php docs/evidence/load.md
git commit -m "feat: t44 ternava concurrency dan benchmark kapasitas"
```

### T45 — CI, audit dan artefak release

**Dependencies:** T44

**Acceptance:** AC-42. Fullvalidator/genDTOdiff/Pint/PHPStan/tests/pub&Composeraudit+gitleaksstaged/history/branchprotectrequiredchecks. Debugfixtures excludedrelease; nosigningpasswordinrepo. Forwardmigration/rollbackbackupdrill; releasefailuredoesnotpublishautomatically.

**Files:**

- Create: `scripts/audit_mobile_dependencies.py`
- Modify: `.github/workflows/ci.yml`
- Create: `mobile/android/app/build.gradle.kts`
- Create: `ops/release.sh`
- Create: `docs/evidence/release.md`

**Interfaces:**

- Consumes: T01versionmanifest; composer.lock/pubspec.lock,allrealAPI/DTOfixtures; signingkeyoutsideGit; cleanGitmetadata.
- Produces: SignedAPK checksum/certificate,backendimagedigest,SPDXorCycloneDXSBOM; passingremotecI commitandlockeddependencyprovenance.

- [ ] **1. Periksa prasyarat dan tulis check/evidence berikut.**

```bash
bash scripts/local-ci.sh --full
# Expected: gagal bila salah satu lock/toolchain/audit/contract/native gate belum tersedia.
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `bash scripts/local-ci.sh --full; bash ops/release.sh --verify-only`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Selesaikan prasyarat/prosedur dan rekam evidence nyata.**

```bash
flutter build apk --release
apksigner verify --verbose --print-certs mobile/build/app/outputs/flutter-apk/app-release.apk
sha256sum mobile/build/app/outputs/flutter-apk/app-release.apk
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `bash scripts/local-ci.sh --full; bash ops/release.sh --verify-only`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add scripts/audit_mobile_dependencies.py .github/workflows/ci.yml mobile/android/app/build.gradle.kts ops/release.sh docs/evidence/release.md
git commit -m "feat: t45 ternava ci audit dan artefak release"
```

### T46 — Validasi farm dan penerimaan pilot

**Dependencies:** T45

**Acceptance:** AC-47. Temukanfarmnyata, validasitotalharian vsputaran,gudang,roles,corrections,timezone/perangkat; bandingkanwaktuinput/kelengkapandenganbaselinefarm tanpa klaimmeningkatanproduksi. Pilihprovider+costapproved; functionalownersactualcontacts; training/recoverydrilldanUATowner. Perubahanrulingmaterial kembaliamendmentspec/plan sebelumbuild/deploy.

**Files:**

- Create: `docs/pilot/farm-validation.md`
- Create: `docs/pilot/device-matrix.md`
- Create: `docs/pilot/operations-agreement.md`
- Create: `docs/pilot/uat-signoff.md`

**Interfaces:**

- Consumes: Spec47AC; all release/restore/native/loadevidence; farmer/operatorparticipationbaruadaketikapilotdisiapkan.
- Produces: Recordedfactsfarm/workflow/devices/provider/budget/contacts/retention; ownerUATsignoff sebelum deploymentdata nyata.

- [ ] **1. Periksa prasyarat dan tulis check/evidence berikut.**

```text
Gagal gate bila belum ada farm, perangkat, provider/biaya, kontak, restore dan UAT.
```

- [ ] **2. Jalankan focused Verify; catat FAIL yang relevan sebelum implementasi.**

Run: `Review docs/pilot/uat-signoff.md terhadap AC-47; hasil PASS hanya bila bukti farm nyata dan persetujuan owner ada.`. Expected awal: FAIL karena output/perilaku task belum tersedia; jangan menerima error fixture sebagai bukti perilaku.

- [ ] **3. Selesaikan prasyarat/prosedur dan rekam evidence nyata.**

```text
Catat nama farm/penanggung jawab dengan izin, tanggal observasi, perangkat yang diuji, biaya disetujui dan referensi evidence; owner menandatangani UAT setelah mencoba flow operasional.
```

- [ ] **4. Ulangi Verify yang sama; hasil harus PASS untuk seluruh Acceptance.**

Run: `Review docs/pilot/uat-signoff.md terhadap AC-47; hasil PASS hanya bila bukti farm nyata dan persetujuan owner ada.`. Record output/commit/perangkat yang relevan di `docs/evidence/`; redact secret.

- [ ] **5. Review scope/kontrak/AC, jalankan gate dokumen dan staged-secret, lalu commit.**

```bash
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
git add docs/pilot/farm-validation.md docs/pilot/device-matrix.md docs/pilot/operations-agreement.md docs/pilot/uat-signoff.md
git commit -m "feat: t46 ternava validasi farm dan penerimaan pilot"
```

## Traceability dan readiness

Semua47 AC,24 screen dan59 operationId harus terpetakan; mapping bersifat rencana coverage, bukan hasil pengujian.

| AC | Task |
|---|---|
| AC-01 | T08, T21, T42 |
| AC-02 | T09, T24 |
| AC-03 | T09, T25 |
| AC-04 | T05, T09, T25 |
| AC-05 | T10, T26 |
| AC-06 | T05, T10, T26 |
| AC-07 | T11, T27 |
| AC-08 | T04, T11, T27 |
| AC-09 | T38, T39 |
| AC-10 | T19, T22, T30, T42 |
| AC-11 | T06, T30, T31 |
| AC-12 | T18, T30, T31, T42 |
| AC-13 | T13, T18, T22, T42 |
| AC-14 | T23, T38 |
| AC-15 | T05, T12, T28 |
| AC-16 | T05, T12, T28 |
| AC-17 | T12, T29, T37 |
| AC-18 | T32, T33 |
| AC-19 | T18, T32, T33, T35, T36, T42 |
| AC-20 | T06, T32, T34 |
| AC-21 | T38, T39 |
| AC-22 | T34, T37, T40 |
| AC-23 | T16, T18, T23, T36, T42 |
| AC-24 | T08, T11, T17, T21, T27, T40, T42 |
| AC-25 | T20, T42 |
| AC-26 | T06, T07, T13, T44 |
| AC-27 | T04, T07, T13, T18, T30, T32, T44 |
| AC-28 | T06, T13, T44 |
| AC-29 | T14, T44 |
| AC-30 | T05, T12, T13, T14, T28, T44 |
| AC-31 | T05, T10, T13, T14, T26, T44 |
| AC-32 | T03, T13, T14, T16, T22, T38, T39 |
| AC-33 | T04, T15, T19, T42 |
| AC-34 | T15, T19, T42, T44 |
| AC-35 | T04, T08, T17, T18, T21, T42 |
| AC-36 | T03, T04, T07, T08, T09, T11, T15, T30, T32, T35, T38, T41 |
| AC-37 | T06, T17, T35, T36 |
| AC-38 | T06, T37, T40 |
| AC-39 | T20, T21, T22, T23, T24, T25, T26, T27, T28, T29, T31, T33, T34, T39, T40, T42 |
| AC-40 | T20, T42 |
| AC-41 | T03, T08, T38, T41 |
| AC-42 | T01, T02, T03, T16, T45 |
| AC-43 | T43 |
| AC-44 | T44 |
| AC-45 | T02, T37, T43 |
| AC-46 | T04, T41, T43 |
| AC-47 | T46 |

## Self-review planning

- Coverage: registry mapping47AC/24screens/59operations, DAG dependencies dan batas files diperiksa `scripts/check_plan.py`.
- Contracts: sources/spec tidak diubah perilakunya saat mencatat D-011/D-012. constraints copied verbatim; exact DTO source tetap OpenAPI.
- Scope: provider/farm/UAT tidak dijadikan fakta; native/security/concurrency/load/restore/release masih pekerjaan kelak.
- Task snippets belum dikompilasi karena pengguna membatasi planning. Pilihan toolchain/package diselesaikan T01–T03 dengan versi nyata sebelum code feature.
- Kandidat seam: `HANDOFF.candidate.md`; belum frozen, belum instruksi mulai execution. Ringkasan kesiapan di `docs/planning-status.md`.
