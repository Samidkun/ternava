# HANDOFF.md — Planning → Execution Contract

> Produced by `sop-planning` (P6), consumed by `sop-execution` (E0).
> Every section is filled, or marked `N/A — <reason>`. **"TBD" is forbidden.**
> An open question becomes a **Ruling** (decision + reason), never a gap.
> Frozen at handoff; changes are amendments recorded in §12.

---

## 1. Identity

| Field | Value |
|---|---|
| Project | TERNAVA — Pencatatan & Monitoring Peternakan Ayam Petelur |
| Tier | T2 |
| Ceremony level | L |
| Spec level | spec-anchored |
| Team size | solo (planning & execution via agent controller) |
| Stack | Flutter stable/Dart (mobile offline Drift/SQLite) + Laravel 13/PHP 8.4/PostgreSQL 18 + Docker |
| Constitution | CONSTITUTION.md |
| Handoff date | 2026-10-01 |
| Frozen by | Samid (User D-011 / D-012 confirmed for execution) |

---

## 2. Goal & Scope

- **Goal (one sentence):** Membangun aplikasi mobile Android offline-first (Flutter) dan backend sync/transactional (Laravel/PostgreSQL) untuk pencatatan harian pakan, telur, mortalitas, tugas SOP, temuan kandang, dan audit stok peternakan ayam petelur.
- **In scope:**
  - Setup farm, kandang (cages), kelompok ayam (flocks/cohorts), role & penugasan petugas (owner, admin, operator).
  - Catatan total harian (daily records) per kelompok per tanggal dengan revisi beralasan dan versioned audit trail.
  - Buku stok pakan (feed ledger): penerimaan, penyesuaian (adjustment), pemakaian otomatis dari catatan harian dengan saldo non-negatif.
  - Tugas operasional (tasks SOP) dan pencatatan hasil kerja.
  - Temuan lapangan (incidents), tindak lanjut (actions), upload foto privat berizin.
  - Kotak masuk durable (inbox) dan notifikasi push opsional (FCM).
  - Sinkronisasi offline-first berbasis lease 24 jam, enkripsi partisi per-akun (Drift SQLite), idempotency key mutasi.
  - Ringkasan statistik (insights) dan ekspor laporan CSV maksimal 183 hari.
- **Out of scope (explicit):**
  - Dashboard web publik / signup mandiri tanpa undangan pengelola.
  - Pelacakan identitas individu ayam (agregat per kelompok/kandang).
  - Multi-gudang dan transfer pakan antar gudang (satu gudang pusat).
  - Integrasi sensor IoT / AI diagnosis penyakit otomatis.
  - Sistem akuntansi komprehensif / laba-rugi penuh / pembayaran gateway.
  - Rilis iOS atau publikasi ke Google Play Store (target pilot instalasi APK langsung).
- **Definition of done (tier-based):**
  - Tier T2: Seluruh 47 kriteria EARS terverifikasi lulus melalui pengujian unit, integrasi API, dan widget.
  - Integritas data terbukti: idempotent replay, concurrency write PostgreSQL, enkripsi lokal Drift per akun.
  - Dokumentasi ganda lengkap (User Manual + Developer Runbook) tersedia di `docs/`.
  - Script verifikasi lokal `scripts/local-ci.sh` lulus bersih tanpa kebocoran rahasia.

---

## 2b. Boundaries

- **Always:**
  - Data kosong (unobserved) diperlakukan berbeda secara tegas dari angka nol.
  - Penyimpanan lokal (local persist) wajib berhasil sebelum mutasi diberi status pending sync.
  - Idempotency-Key unik dan tetap pada setiap percobaan pengiriman ulang.
  - Status "Diterima / Terkirim" hanya diberikan setelah commit database server berhasil.
  - Pemeriksaan ACL dan role pada setiap endpoint backend tanpa terkecuali.
  - Setiap revisi data operasional wajib mencatat alasan, timestamp, dan nomor versi baru.
  - Partisi database lokal Drift terenkripsi dan terisolasi per user id.
  - Perubahan spesifikasi dan kode aplikasi mendarat dalam satu commit yang sama (spec-anchored).
- **Ask first:**
  - Penambahan dependensi paket native atau pihak ketiga di luar yang telah disepakati.
  - Perubahan batas arsitektur (misal: penambahan service backend terpisah di luar Laravel monolith).
  - Pengubahan skema database yang bersifat merusak (destructive migration) pada data pilot.
- **Never:**
  - Plaintext password, token sesi, atau secret key tersimpan dalam kode, git repository, atau log aplikasi.
  - Memberikan rekomendasi dosis medis atau diagnosis otomatis tanpa input manual petugas.
  - Mengubah payload antrean offline secara diam-diam saat terjadi konflik sinkronisasi.
  - Mengklaim fitur atau pengujian berhasil tanpa bukti perintah verifikasi yang dijalankan nyata.

---

## 2c. Capability Map

| Module id | Responsibility | Depends on |
|---|---|---|
| `farm-access` | Otentikasi, manajemen pengguna, peran, penugasan kandang, dan validasi sesi offline lease | — |
| `flocks` | Manajemen master kandang, kelompok ayam (cohorts), strain, dan kapasitas populasi | `farm-access` |
| `feed-ledger` | Master jenis pakan, saldo stok gudang, penerimaan, penyesuaian, dan konsumsi harian | `farm-access`, `flocks` |
| `daily-operations` | Form total harian pakan/telur/mortalitas, revisi berversi, tugas SOP, dan foto attachment | `farm-access`, `flocks`, `feed-ledger` |
| `incidents` | Pelaporan temuan kandang, eskalasi status, dan log tindakan penanganan | `farm-access`, `flocks`, `daily-operations` |
| `insights` | Notifikasi inbox lokal, ringkasan kepatuhan pencatatan, dan ekspor laporan CSV | seluruh modul terkait |

Build order: `farm-access` → `flocks` → `feed-ledger` → `daily-operations` → `incidents` → `insights`

---

## 3. Prompt-Roast Result

- Six-axis score: 10 / 12 (Goal: 2, Context: 2, Scope: 2, Success: 1, Constraints: 2, Ambiguity: 1)
- Gaps named and how they were answered:
  - Kondisi peternakan nyata belum ada: disepakati menggunakan dataset pilot contoh (20 kandang, 10 user) pada Docker lokal (D-008, D-010).
  - Detail serah akun: disepakati pembuatan akun menyertakan sandi sementara minimal 12 karakter yang wajib diganti (AM-01 / D-011).
  - Revisi kelompok: disepakati riwayat perubahan kelompok wajib menyertakan alasan (AM-02 / D-011).
- False premise checked against repo: Selesai diverifikasi. Tidak ada klaim bahwa aplikasi sudah terpasang atau farm nyata sudah berjalan.
- **Assumptions surfaced:** Dicatat sebagai Rulings R-01 s/d R-21 di `docs/planning-rulings.md` (Android target, tema terang, gudang pusat, lease offline 24 jam, zona Asia/Jakarta, mata uang IDR).
- **Clarify gate (P1.5):** no material ambiguity open — yes (seluruh ambiguitas operasional telah diselesaikan).

---

## 4. Design Contract

**4a. `DESIGN.md` spine**
- Subject / audience / primary job: Aplikasi pendamping operasional peternak ayam petelur untuk pencatatan harian yang cepat, tangguh saat offline, dan akuntabel bagi pemilik.
- Voice: Lugas, fungsional, andal, tanpa jargon teknis berlebihan.
- Token spine:
  - Typography: Fira Sans 400 (Body) / 600 (Semibold / Heading).
  - Colors: Primary Green `#195647`, Canvas `#F2F6F3`, Surface `#FFFFFF`, Border `#D2DDD5`, Text Dark `#1A2E26`, Text Muted `#526B60`.
  - Spacing: 4px, 8px, 12px, 16px, 24px, 32px.
  - Radius: 8px (controls), 10px (cards), 16px (containers).
  - Target Sentuh: Minimal 48 dp untuk kemudahan interaksi di lapangan.
- **Signature bet:** Indikator status pencatatan kandang bertanggal dengan pemisahan eksplisit antara "Belum Dicatat" vs "Nol Butir", serta ringkasan kelengkapan data sebelum angka agregat ditampilkan.
- Knobs: `DESIGN_VARIANCE=4`, `VISUAL_DENSITY=6`, `MOTION_INTENSITY=2` (durasi transisi 140ms dengan dukungan prefers-reduced-motion).
- **Anti-Slop Test:** "would you believe AI made this?" → **No** (menggunakan palet earthy-agricultural fungsional, tanpa gradien neon, tanpa kartu generik bertumpuk).
- Banned-pattern check: Tidak ada emoji sebagai icon fitur, tidak ada teks ALL-CAPS panjang, tidak ada dashboard generik tanpa alur kerja.

**4a-bis. Screen Inventory**

| # | Screen id | Screen | Archetype | Primary job | Entry from | States | AC | Mockup | ACC |
|---|-----------|--------|-----------|-------------|------------|--------|----|--------|-----|
| 1 | `login` | Masuk ke TERNAVA | Guided Flow | Masuk akun dengan autentikasi online/offline lease | direct | default, loading, error, offline-first, expired, success | AC-01 | `preview/mockup/login.html` | yes / 2026-10-01 |
| 2 | `farm-setup` | Pengaturan peternakan | Guided Flow | Konfigurasi profil peternakan dan zona waktu | `account` | default, loading, error, offline, success | AC-02 | `preview/mockup/farm-setup.html` | yes / 2026-10-01 |
| 3 | `cage-list` | Daftar Kandang | List-Detail | Melihat daftar kandang dan status pencatatan harian | `home` / nav | default, empty, loading, error, stale, restricted | AC-03 | `preview/mockup/cage-list.html` | yes / 2026-10-01 |
| 4 | `cage-form` | Kandang Baru | Guided Flow | Menambah data master kandang baru | `cage-list` | default, error, offline, success | AC-04 | `preview/mockup/cage-form.html` | yes / 2026-10-01 |
| 5 | `flock-list` | Kelompok Ayam | List-Detail | Melihat riwayat dan populasi kelompok ayam | `cage-list` | default, empty, loading, error, finished | AC-05 | `preview/mockup/flock-list.html` | yes / 2026-10-01 |
| 6 | `flock-form` | Kelompok Baru / Edit | Guided Flow | Pendaftaran dan pembaruan data kelompok ayam | `flock-list` | default, edit, error, duplicate, offline, success | AC-06 | `preview/mockup/flock-form.html` | yes / 2026-10-01 |
| 7 | `team-list` | Tim Peternakan | List-Detail | Mengelola anggota tim dan hak akses kandang | `account` | default, empty, loading, error | AC-07 | `preview/mockup/team-list.html` | yes / 2026-10-01 |
| 8 | `member-form` | Anggota Baru / Edit | Guided Flow | Pendaftaran petugas dengan sandi sementara | `team-list` | default, edit, error, offline, success | AC-08 | `preview/mockup/member-form.html` | yes / 2026-10-01 |
| 9 | `home` | Beranda Pemilik | Executive Dashboard | Ringkasan kondisi peternakan, alert, dan produksi | login | default, empty, loading, error, stale | AC-09 | `preview/mockup/home.html` | yes / 2026-10-01 |
| 10 | `today` | Tugas Hari Ini | Guided Flow | Alur kerja utama operator untuk checklist harian | login | default, empty, loading, error, offline, stale | AC-10 | `preview/mockup/today.html` | yes / 2026-10-01 |
| 11 | `task-form` | Template Tugas | Guided Flow | Membuat instruksi tugas SOP berkala | `today` | default, error, offline, success | AC-11 | `preview/mockup/task-form.html` | yes / 2026-10-01 |
| 12 | `task-detail` | Rincian Tugas | List-Detail | Pelaporan hasil pengerjaan SOP lapangan | `today` | default, loading, error, offline, success | AC-12 | `preview/mockup/task-detail.html` | yes / 2026-10-01 |
| 13 | `daily-form` | Catatan Harian | Guided Flow | Input total telur, pakan, dan mortalitas | `today` | default, edit, error, offline, success | AC-13 | `preview/mockup/daily-form.html` | yes / 2026-10-01 |
| 14 | `daily-history` | Riwayat Catatan | List-Detail | Memeriksa audit log dan status revisi catatan | `cage-list` | default, empty, loading, error | AC-14 | `preview/mockup/daily-history.html` | yes / 2026-10-01 |
| 15 | `feed-stock` | Stok Pakan | Dense Ledger | Monitoring saldo fisik dan mutasi stok pakan | `home` / nav | default, empty, loading, error, low | AC-15 | `preview/mockup/feed-stock.html` | yes / 2026-10-01 |
| 16 | `feed-entry` | Mutasi Pakan | Guided Flow | Input penerimaan atau penyesuaian pakan | `feed-stock` | default, error, offline, success | AC-16 | `preview/mockup/feed-entry.html` | yes / 2026-10-01 |
| 17 | `feed-type-form` | Jenis Pakan | Guided Flow | Pendaftaran master merek dan jenis pakan | `feed-stock` | default, error, offline, success | AC-17 | `preview/mockup/feed-type-form.html` | yes / 2026-10-01 |
| 18 | `incident-list` | Temuan Masalah | List-Detail | Daftar kendala kesehatan atau fasilitas kandang | `today` / nav | default, empty, loading, error | AC-18 | `preview/mockup/incident-list.html` | yes / 2026-10-01 |
| 19 | `incident-form` | Laporkan Masalah | Guided Flow | Pelaporan insiden baru beserta lampiran foto | `incident-list` | default, error, offline, success | AC-19 | `preview/mockup/incident-form.html` | yes / 2026-10-01 |
| 20 | `incident-detail` | Rincian Masalah | List-Detail | Tindak lanjut, update penanganan, dan penyelesaian | `incident-list` | default, loading, error, offline, success | AC-20 | `preview/mockup/incident-detail.html` | yes / 2026-10-01 |
| 21 | `reports` | Laporan Produksi | Executive Dashboard | Analisis tren produksi, rasio pakan, dan ekspor CSV | `home` / nav | default, empty, loading, error | AC-21 | `preview/mockup/reports.html` | yes / 2026-10-01 |
| 22 | `inbox` | Pesan & Peringatan | List-Detail | Notifikasi in-app untuk eskalasi kendala | `home` / nav | default, empty, loading, error | AC-22 | `preview/mockup/inbox.html` | yes / 2026-10-01 |
| 23 | `sync-center` | Status Sinkronisasi | Workspace | Monitoring antrean offline, retry, dan log sync | nav / status | default, empty, syncing, error, conflict | AC-23 | `preview/mockup/sync-center.html` | yes / 2026-10-01 |
| 24 | `account` | Akun & Pengaturan | Guided Flow | Profil pengguna, keamanan sandi, dan switch peternakan | nav | default, loading, error, offline, success | AC-24 | `preview/mockup/account.html` | yes / 2026-10-01 |

- Flow: Login → Identifikasi Role → Operator (`today` → `daily-form` → `sync-center`) / Pemilik (`home` → `cage-list` → `feed-stock` → `reports`).
- Screens deliberately excluded: Tidak ada landing page web, onboarding wizard multi-slide, atau dashboard admin browser terpisah.
- Screen-count sanity check passed: Semua 24 layar terhubung dalam navigasi, memiliki tepat 1 peran utama, dan memetakan acceptance criteria terkait.

**4a-ter. Mockup & approval gate (P2.1)**
- **Renderer used:** Hand-crafted HTML/CSS self-contained mockups with inline token systems and zero external network assets.
- **Approved screens:** `login`, `farm-setup`, `cage-list`, `cage-form`, `flock-list`, `flock-form`, `team-list`, `member-form`, `home`, `today`, `task-form`, `task-detail`, `daily-form`, `daily-history`, `feed-stock`, `feed-entry`, `feed-type-form`, `incident-list`, `incident-form`, `incident-detail`, `reports`, `inbox`, `sync-center`, `account` (Seluruh 24 layar disetujui via D-009 dan D-011 pada 2026-10-01).
- **Screens NOT yet approved:** Tidak ada. Seluruh 24 layar inventaris telah disetujui.

**4b. UI hygiene**
- Playbook loaded: `reference/operate.md` (Operational tools & data entry).
- **Design system:** establish (token spine, komponen kartu kandang, form input bertarget sentuh 48dp, status pills).
- Figma involved: N/A — desain dikerjakan langsung dalam kode mockup HTML mandiri.
- **States required:** Seluruh layar wajib mengimplementasikan state `empty`, `loading`, `error`, dan `offline` sesuai tabel inventaris.
- UI detail checklist in scope: Keyboard friendly, visible touch feedback, label formulir persisten, dialog konfirmasi aksi destruktif, sanitasi teks panjang, error state deskriptif dengan tombol retry.
- UI detail checklist excluded: Dark mode (dikecualikan untuk rilis pilot agar konsisten di bawah terik matahari kandang).

**4c. UX floor (P2.4)**
- User flow + IA: Sesuai struktur inventaris §4a-bis dan `docs/flows-and-screens.md`.
- Nielsen's 10 heuristics weak points: Status koneksi/sinkronisasi (diatasi via `sync-center` dan badge offline), pencegahan error input pakan (diatasi via penolakan saldo negatif dan validasi rentang angka).
- Microcopy rules: Pesan error wajib menjelaskan solusi (bukan hanya kode status), label tombol aksi deskriptif ("Simpan Catatan", bukan "Kirim").
- UX coverage walked: Selesai diuji dan didokumentasikan di `docs/ux-review.md`.

**4d. Diagrams as code (P2.6)**
- ERD (`erDiagram`): `docs/diagrams/erd.md` (dihasilkan otomatis dari `contracts/schema.json`, 26 tabel).
- User flow (`flowchart`): `docs/diagrams/daily-flow.md` dan `docs/diagrams/incident-flow.md`.
- Sequence (`sequenceDiagram`): `docs/diagrams/sequence-createDaily.md`, `docs/diagrams/sequence-reviseDaily.md`, `docs/diagrams/sequence-pullChanges.md`.
- Architecture (`flowchart`): `docs/diagrams/architecture.md`.
- All in-repo, versioned, regenerated from source: yes.

---

## 5. Acceptance Criteria

47 Kriteria EARS lengkap terdokumentasi di `docs/superpowers/specs/2026-10-01-ternava-design.md` dan `contracts/criteria.json`. Ringkasan per modul:

| Id | Pattern | EARS statement | Verify (test / command / observable) |
|---|---|---|---|
| AC-01 | event | WHEN login online berhasil, THE aplikasi SHALL membuka workspace role setelah referensi awal tersedia. | API + Flutter integration test login valid/invalid |
| AC-02 | event | WHEN pengelola menyimpan farm valid, THE aplikasi SHALL menampilkan nama dan zona waktu yang diterima server. | API feature test farm setup |
| AC-03 | state | WHILE operator membuka daftar kandang, THE aplikasi SHALL menampilkan hanya kandang dalam assignment aktif. | Integration test filtering cage assignment |
| AC-04 | event | WHEN pengelola menyimpan kandang berkode unik, THE sistem SHALL menyediakannya tanpa menimpa kode yang sudah dipakai. | API constraint test unique cage code |
| AC-05 | state | WHEN pengguna membuka kelompok kandang yang berizin, THE aplikasi SHALL memisahkan kelompok aktif dan selesai. | Widget & API test flock status filter |
| AC-06 | event | WHEN pengelola menambah kelompok dengan populasi awal valid, THE sistem SHALL menginisiasi ledger populasi kelompok. | API transaction test cohort initialization |
| AC-07 | event | WHEN pengelola menugaskan operator ke kandang, THE sistem SHALL memperbarui izin pencatatan harian operator tersebut. | API RBAC test assignment |
| AC-08 | event | WHEN pengelola menambah pengguna baru, THE sistem SHALL menghasilkan kredensial awal dengan sandi sementara minimal 12 karakter. | API test member creation (AM-01) |
| AC-09 | state | WHILE pemilik membuka ringkasan hari ini, THE aplikasi SHALL menampilkan kelengkapan laporan sebelum angka agregat. | Widget test owner home completeness indicator |
| AC-10 | event | WHEN operator menyimpan catatan harian saat offline dalam masa lease, THE aplikasi SHALL menyimpan mutasi lokal dan menandainya siap kirim. | Flutter Drift local test offline save |
| AC-11 | event | WHEN pengelola membuat template tugas, THE sistem SHALL menjadwalkan tugas pada tanggal aktif kandang terkait. | API test task template generation |
| AC-12 | event | WHEN operator mencentang checklist tugas lapangan, THE aplikasi SHALL mencatat timestamp dan user penyelesai. | Widget + sync queue test task completion |
| AC-13 | event | WHEN operator menyimpan total pakan dan telur, THE sistem SHALL memvalidasi jumlah dan memotong stok pakan gudang dalam satu transaksi. | Integration test atomic daily + feed stock ledger |
| AC-14 | state | WHILE pengelola membuka riwayat catatan, THE aplikasi SHALL menampilkan audit log revisi dan membedakan draft dari accepted record. | Widget & API test daily audit trail |
| AC-15 | state | WHILE pengguna membuka stok pakan, THE sistem SHALL menampilkan saldo riil terkini berdasarkan buku besar mutasi. | DB transaction test feed ledger balance |
| AC-16 | unwanted | IF mutasi pakan mengakibatkan saldo gudang negatif, THEN THE sistem SHALL menolak transaksi dengan pesan error saldo tidak mencukupi. | DB constraint & API test negative stock guard |
| AC-17 | event | WHEN pengelola menyimpan jenis pakan baru, THE sistem SHALL mendaftarkannya sebagai referensi pencatatan pakan. | API test feed catalog creation |
| AC-18 | event | WHEN operator melaporkan temuan masalah kandang, THE sistem SHALL mencatat tingkat urgensi dan memunculkannya di inbox tim. | API & widget test incident escalation |
| AC-19 | event | WHEN lampiran foto temuan diunggah, THE sistem SHALL menyimpan file pada storage privat dan memvalidasi tipe serta ukuran file (maks 5MB). | Storage & ACL test attachment upload |
| AC-20 | event | WHEN pengelola memperbarui status temuan menjadi selesai, THE sistem SHALL mewajibkan catatan tindakan penanganan. | API validation test incident resolution |
| AC-21 | event | WHEN pemilik meminta ekspor data laporan, THE sistem SHALL menghasilkan file CSV dengan rentang tanggal maksimal 183 hari. | API test CSV export range guard |
| AC-22 | state | WHILE terdapat notifikasi insiden belum dibaca, THE aplikasi SHALL menampilkan indikator badge pada menu inbox. | Widget test inbox unread badge |
| AC-23 | event | WHEN sinkronisasi dijalankan, THE aplikasi SHALL mengirim antrean mutasi menggunakan Idempotency-Key yang konsisten. | Integration test sync idempotent retry |
| AC-24 | unwanted | IF masa lease offline 24 jam telah berakhir, THEN THE aplikasi SHALL mengunci input mutasi baru hingga verifikasi online berhasil. | Flutter core test offline lease expiry |
| AC-25 | state | WHILE pengguna berpindah antar modul, THE navigasi aplikasi SHALL mempertahankan konsistensi state tanpa kehilangan data input yang belum tersimpan. | Flutter widget test form dirty guard |
| AC-26 s/d AC-47 | all | Integritas transaksi, idempotensi, audit trail, pencegahan SSRF/IDOR, backup drill, dan kriteria kesiapan pilot. | Suite tes keamanan, database constraints, dan scripts/local-ci.sh |

---

## 5b. Drift Contract

- Spec artifact path: `docs/superpowers/specs/2026-10-01-ternava-design.md`
- Criteria live in: `contracts/criteria.json` dan dokumen spec di atas.
- Rule: Perubahan spesifikasi dan kode aplikasi mendarat dalam **commit yang sama**; ketidakcocokan antara spec, kontrak, dan implementasi adalah kondisi **pemblokir merge (blocking)**. Refaktor murni wajib mencantumkan pesan: `spec: no change — <reason>`.
- Drift gate command / CI slot: `python3 scripts/check_contracts.py && python3 scripts/generate_diagrams.py --check && python3 scripts/check_plan.py`

---

## 6. Feature Completeness

- **In scope (ticked):**
  - Autentikasi token Sanctum + partisi data lokal Drift terenkripsi AES-GCM.
  - CRUD Master: Farm, Kandang, Kelompok Ayam, Pengguna, Jenis Pakan.
  - Transaksi Inti: Catatan Harian (Telur, Pakan, Kematian) + Pemotongan Stok Atomik.
  - Audit Trail: Revisi catatan harian wajib alasan dan versi increment.
  - Operasional Lapangan: Checklist tugas SOP dan Pelaporan Insiden + Upload Foto.
  - Sinkronisasi: Outbox pattern dengan idempotency key dan penanganan konflik deterministik.
  - Laporan & Monitoring: Ringkasan kepatuhan input, saldo pakan, dan ekspor CSV.
- **Deliberate exclusions (with reason):**
  - Sensor IoT: Peternakan pilot masih mengandalkan pencatatan manual operator.
  - Multi-gudang: Disederhanakan menjadi satu gudang konsumsi utama peternakan (YAGNI).
  - Diagnosis AI: Menghindari halusinasi medis; pengamatan murni deskripsi faktual lapangan.
- **Security/reliability rows for this tier:**
  - STRIDE threat model: Terdokumentasi lengkap pada `docs/operations-security.md`.
  - SLO / error budget: Ketersediaan API 99.5%, p95 response time < 500ms, RPO 24 jam / RTO 4 jam.
  - SSRF surface: N/A — backend tidak melakukan fetch URL eksternal bebas; push notification terbatas ke endpoint resmi Firebase FCM.
  - WCAG level: Target aplikasi mobile Android mengacu pada kontras warna minimal 4.5:1, target sentuh 48dp, dan kompatibilitas TalkBack Android.

---

## 7. Interfaces & File Paths

- **Files to create:**
  - `mobile/lib/core/api/` (generated DTOs and API client facade)
  - `mobile/lib/core/database/` (encrypted Drift SQLite schema & DAOs)
  - `mobile/lib/core/sync/` (outbox sync worker, lease manager)
  - `mobile/lib/features/` (24 screens with ViewModels following MVVM architecture)
  - `backend/app/Contracts/` (generated response DTOs and request validators)
  - `backend/app/Models/` (26 Eloquent models mapped to `contracts/schema.json`)
  - `backend/app/Services/` (atomic mutation services: DailyRecordService, FeedStockService, SyncService)
  - `backend/database/migrations/` (PostgreSQL DDL with foreign keys, checks, and unique indexes)
- **Files to modify:**
  - `scripts/local-ci.sh` (integrasi pemeriksaan aplikasi saat monorepo dibuat)
  - `.github/workflows/ci.yml` (CI runner matrix)
- **Interfaces between tasks:**
  - Task T01-T07 memproduksi DTOs dan migration schemas yang dikonsumsi oleh Backend Services (T08-T15).
  - Backend Services memproduksi REST contract responses yang dikonsumsi oleh Mobile Repository & Sync Worker (T16-T23).
  - Seluruh bentuk interface diikat oleh `contracts/openapi.json` dan `contracts/schema.json`.

---

## 7b. Interface Contracts

- **Layers & responsibilities:**
  - Frontend (Flutter): UI rendering, offline cache persistence (Drift), local outbox queue, input validation.
  - Backend (Laravel): Otorisasi peran (RBAC), koordinasi transaksi DB, deduplikasi Idempotency-Key, penyajian data sinkronisasi.
  - Database (PostgreSQL): Penyimpanan data permanen, integritas relasional, isolasi ACID mutasi stok dan catatan harian.
- **Boundary contracts:** 59 Operasi OpenAPI didefinisikan di `contracts/openapi.json` dengan format wire JSON snake_case, IDR numeric(15,2), kg numeric(10,2).
- **Shared types:** UUID v4 identifier, YYYY-MM-DD business date, RFC3339 UTC timestamp.
- **Error envelope:** `{ "error": { "code": string, "message": string, "fields": object?, "request_id": string, "retryable": boolean, "current_version": int? } }`
- **Auth:** Bearer Token via Laravel Sanctum (masa berlaku 7 hari), validasi lease offline pada aplikasi mobile (24 jam).
- **Enforcement:** DTO code generation pada Flutter dan Laravel, automated contract tests pada CI suite.

---

## 8. Constraints

- Versions: Flutter stable (3.x+), Dart 3.x, PHP 8.4, Laravel 13, PostgreSQL 18, Docker Compose v2.
- Non-negotiables: Saldo pakan tidak boleh negatif, catatan harian per kandang unik per tanggal, revisi wajib memiliki alasan, otentikasi wajib pada setiap request.
- Environment: Local Docker container untuk backend dan database, Android emulator/device untuk pengujian mobile.

---

## 9. Plan Artifact

- Plan required? yes (multi-task architectural build, 46 tasks terstruktur).
- Path to plan file: `docs/superpowers/plans/2026-10-01-ternava-mvp.md`
- Global constraints section included verbatim: yes.

---

## 10. Factory Bootstrap

- Bootstrap run? yes (direktori dasar, skrip verifikasi, dan git repository telah diinisialisasi; setup scaffold framework Flutter & Laravel dipetakan pada Task T01-T03).
- Manual steps outstanding: Penyiapan akun Firebase project untuk FCM (dapat dijalankan lokal tanpa FCM aktif dengan inbox lokal).
- Result recorded: `docs/factory-readiness.md` dan `scripts/local-ci.sh --planning` lulus bersih.

---

## 11. Accepted Risks

| Risk | Why accepted | Owner |
|---|---|---|
| Ketiadaan peternakan pilot nyata saat awal pembangunan | Desain menggunakan skenario pengujian baseline 20 kandang / 10 pengguna agar arsitektur teruji sebelum deployment fisik | Samid (Owner) |
| Push notification FCM non-aktif pada Docker lokal | Sistem dirancang dengan inbox lokal durable sehingga tidak ada kehilangan notifikasi kritis saat FCM tidak tersedia | Samid (Owner) |

---

## 12. Amendments

| Date | Change | Reason | Re-approved by |
|---|---|---|---|
| 2026-10-01 | AM-01 Penambahan kolom sandi sementara pada `member-form` | Memperjelas serah terima akun awal bagi petugas lapangan | Samid (D-011) |
| 2026-10-01 | AM-02 Penambahan input alasan perubahan pada edit `flock-form` | Memastikan jejak audit histori populasi kelompok ayam terjaga | Samid (D-011) |
| 2026-10-01 | Pembekuan formal HANDOFF.md untuk eksekusi Phase 2 | Menyelesaikan transisi formal dari Phase 1 (Planning) ke Phase 2 (Execution) | Samid |

---

## 13. P7 Readiness Gate

- [x] Tier + team + **ceremony level** written (§1)
- [x] **Spec level** declared (§1)
- [x] **Constitution** present or waived (§1)
- [x] **Boundaries** recorded (§2b)
- [x] **Capability map** approved if multi-capability (§2c)
- [x] Prompt-roast scored; gaps answered (§3)
- [x] False premise checked against repo (§3)
- [x] **Assumptions** surfaced; expensive ones are Rulings (§3)
- [x] **Clarify gate** passed (§3)
- [x] Brainstorm approval obtained, in writing (§2/P1)
- [x] Design contract present if UI exists; every state named (§4)
- [x] Acceptance criteria **EARS-shaped**, each with id + Verify (§5)
- [x] **Drift contract** recorded (§5b)
- [x] Feature Completeness walked; exclusions stated (§6)
- [x] Security/reliability rows for the tier named (§6)
- [x] Interfaces exact; no "similar to" (§7)
- [x] File paths listed (§7)
- [x] Constraints copied verbatim (§8)
- [x] No TBD/TODO anywhere — open questions are Rulings
- [x] Factory bootstrap run or deferral stated (§10)
- [x] Spec approved by the human (architectural path)

**Frozen:** [x]  ·  **Handoff path:** `/mnt/data/porto/ternava/HANDOFF.md`  ·  **Seen by human:** [x]
