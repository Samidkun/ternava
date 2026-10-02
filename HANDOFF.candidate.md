# TERNAVA — HANDOFF kandidat planning

**Status: NOT FROZEN; planning-only D-012.** Ini merangkum kontrak perencanaan, bukan otorisasi menjalankan task. Tidak ada `HANDOFF.md` frozen atau app yang sudah dibangun. Template seam: sop-planning P6/P7.

## 1. Identity

| Field | Value |
|---|---|
| Project | TERNAVA, ayam petelur |
| Tier / Ceremony / Spec level | T2 / L / spec-anchored |
| Team | Ruling: planning dalam chat ini bersama pengguna; jumlah kolaborator eksekusi ditetapkan saat eksekusi diminta |
| Stack | Flutter stable/Dart, Drift, Laravel13/PHP8.4/PostgreSQL18, Docker lokal; patch/digest dikunci T01 |
| Constitution | CONSTITUTION.md |
| Candidate date | 1 Oktober 2026, Asia/Jakarta |
| Frozen by | N/A — kandidat belum frozen; pengguna membatasi planning |
| Root pilihan | /mnt/data/porto/ternava; paket planning terbaru sudah disalin setelah write grant diberikan; salinan output tersedia |

## 2. Goal, scope dan definition of done

Goal: operator mempertahankan catatan saat offline, pengelola meninjau accepted data dan ledger yang konsisten. Scope dan exclusions normatif disalin di §8. Done pilot memerlukan47AC beserta evidence native/server/security/load/restore/release dan UAT farm nyata. Dokumen planning lulus tidak membuat pilot selesai.

### 2b. Boundaries

- Always: data kosong berbeda nol, local persist sebelum pending, stable key, ACK hanya commit server, ACL setiap operasi/replay/file/export, revision audit, encrypted partition, spec+code satu commit.
- Ask first: perubahan material scope/kontrak/aturan diterima, biaya/provider atau deployment yang belum diotorisasi, komunikasi kepada pihak lain. Sekarang tunggu permintaan eksekusi pengguna, sesuai D-012.
- Never: plaintext password/token/key dalam repo/log/cache, diagnosis/dosis otomatis, silently mengganti payload pending, destructive migration pilot, klaim farm/benefit/test PASS tanpa evidence.

### 2c. Capability map

| Module | Responsibility | Depends on |
|---|---|---|
| farm-access | Identity, role, assignment, session | — |
| flocks | Kandang, kelompok, rentang/populasi | farm-access |
| feed-ledger | Referensi, saldo, immutable origin | farm-access, flocks |
| daily-operations | Total/revision, tugas, foto | farm-access, flocks, feed-ledger |
| incidents | Pengamatan, assignment, tindakan | farm-access, flocks, daily-operations |
| insights | Inbox, ringkasan, laporan | seluruh modul terkait |

Map diterima bersama D-011. Build order berdasarkan DAG46task, dengan slice operator T23 sebelum perluasan admin.

## 3. Prompt-roast dan assumptions

Score kelanjutan desain10/12: goal2/context2/scope2/success1/constraints2/ambiguity1. Premise dicek: project berisi artifacts planning, belum app/SDK/lockfiles; tidak ada farm nyata. R-01–R-21 menetapkan Android/Indonesian/light, warehouse pusat, total harian, lease24h, kapasitas contoh, retensi/reliability dan gate pilot. Pilihan tersebut baseline desain yang diterima D-011, bukan hasil wawancara farm.

Clarify desain cukup untuk rencana contoh. Fakta lapangan diperoleh AC-47 sebelum pilot; perubahan material kembali amendment. Metadata dan exact patch diselesaikan T01 sebelum feature code. Tidak ada tenggat/anggaran hasil tebakan.

## 4. Design contract

Spine DESIGN.md: Fira Sans400/600, primary#195647, bg#F2F6F3, body16/title26, spacing4/8/12/16/24/32, radius8/10/16/24, target48dp, motion140ms/reduced. Signature: status kandang bertanggal, kelengkapan terlihat sebelum angka agregat. Knobs variance4/density6/motion2. Design system establish, native components; Figma N/A — tidak digunakan.

Inventory authoritative: docs/flows-and-screens.md,24screen/132state; preview/manifest.json. Mockup satu HTML/screen. D-009 menerima baseline paket24screen untuk lanjut, D-011 menerima member-form AM-01 dan flock-form AM-02. Ini penerimaan percakapan, bukan klaim semua file/state diamati pengguna. ACC per screen: docs/preview-review.md.

UX floor/hygiene: docs/ux-review.md; error memberi pemulihan, empty mengajarkan input, no preset jumlah, no AC-900 toolbar native. Weakness yang perlu diuji di lapangan: recognition/terminologi operasional, recovery sync, bantuan pengguna. Native TalkBack/text200%/48dp masih gate T42. Anti-slop dan source token review tersedia; keputusan visual akhir native belum dibuktikan oleh source parsing.

Diagrams as code: docs/diagrams/README.md memetakan ERD, architecture, F03/F06 dan sequence create/revise/pull; generated dari contracts JSON, drift checker scripts/generate_diagrams.py. Render seluruh diagram bukan evidence yang diklaim pada tahap ini.

## 5. Acceptance criteria

47 EARS statements dan Verify utuh: docs/superpowers/specs/2026-10-01-ternava-design.md. Machine source: contracts/criteria.json. Mapping implementasi: contracts/plan.json dan tabel plan. Tidak menyalin ulang criteria agar source tetap satu; checker memastikan teks spec/JSON sama.

### 5b. Drift contract

Spec-anchored: perubahan perilaku memasukkan spec+criteria/contracts+code/fixtures+diagram dalam commit sama. Divergence blocking merge; pure refactor menyebut `spec: no change — reason`. Gate dokumen scripts/check_contracts.py/generate_diagrams.py/check_plan.py, lalu full response DTO/API tests pada CI execution.

## 6. Completeness, security dan reliability

In scope/exclusions §8; enam modul, total+revision+ledger/tasks/incidents/photos/inbox/report/account/recovery. STRIDE rows/limits/private files/ACL/encryption/session di docs/operations-security.md. SLO99.5% perbulan, RPO24h/RTO4h adalah target yang harus diukur. SSRF N/A — backend tidak fetch arbitrary URL; push memakai fixed FCM provider. WCAG web audit N/A — target native Android; contrast4.5:1/TalkBack/text200/48dp tetap diuji. Backup, retention/deletion journal, observability dan signed release terpetakan T41–T46.

## 7. Interfaces dan file paths

Daftar exact paths, consumes/produces/signatures dan test commands per task: docs/superpowers/plans/2026-10-01-ternava-mvp.md. Generated DTO memakai schema names OpenAPI; internal ActorScope(actorId,farmId,role,cageIds), MutationExecutor::run(...):Ack, ApiClient.request(operationId,body,key), PartitionStore.transaction dan cache/outbox ACK atomic. contracts/plan.json menyimpan registry46task dan DAG.

### 7b. Boundary contracts

OpenAPI3.1: contracts/openapi.json,41paths/59operations; JSON schema model26tabel logis. Protocol normative docs/api-sync.md. Laravel controllers melakukan DTO/policy, services transaction, PostgreSQL invariant. Flutter typed DTO/viewmodel/repository; encryptedlocal berbeda serveraccepted. Wire snake_case, kg stringfixed2, IDRfixed2, UTC/datefarm, nullunobserved. Uniform error(code,message,fields,request_id,retryable,current_version), 401/403/404/409/422/429/500/503 recovery. Sanctum7d, offlinelease24h, authorization sebelum receipt replay. Enforcement T03/full validator+typed DTO+response tests; T07/T13/T14 concurrency PostgreSQL dan T18/T19 fault Drift.

## 8. Constraints verbatim

Android, bahasa Indonesia, tema terang, satu farm contoh (Asia/Jakarta/IDR), sampai20 kandang/10 akun/20 perangkat sebagai kapasitas template. Owner/admin/operator, satu gudang pusat, satu cohort per kandang per tanggal. Tanggal/rentang/kuantitas mengikuti `api-sync.md`; angka ini ruling desain untuk review, bukan fakta farm. Kondisi medis diinput pengamatan manual, tidak otomatis didiagnosis. Field jumlah wajib untuk kirim, nol eksplisit, draft boleh belum lengkap; satu harian adalah total, bukan event per shift.

Termasuk: akses/setup, kandang/cohort, role/assignment, total harian+revisi, stok/receipt/adjustment, tugas/SOP+hasil, temuan/action, foto privat, inbox/push, ringkasan/reportCSV, offlinequeue dan akun. Tidak termasuk: dashboardweb, onboardingcarousel, signup publik, individu tiap ayam, transfer gudang, IoT/AI, diagnosis/dosis, akuntansi/laba, PDF, chat, pembayaran, iOS/PlayStore release. Splash hanya transisi awal, bukan scope halaman marketing.

Kebijakan sesi/role/revisi/retensi/reliability di `api-sync.md` dan `operations-security.md` merupakan bagian spesifikasi yang diterima melalui D-011. Deployment nyata menunggu gate AC-47; development lokal boleh memakai data rekaan. Tenggat/anggaran proyek tidak ditebak. Provider berbayar dan kontak petugas nyata ditetapkan sebelum deployment, sesuai D-010.


Keluarga runtime dari docs/architecture.md: Laravel **13**, PHP **8.4**, PostgreSQL **18**. Plan Global Constraints memuat paragraph versi lengkap serta paragraph desain verbatim.

## 9. Plan artifact

Required: ya, multi-task. Path docs/superpowers/plans/2026-10-01-ternava-mvp.md,46focused tasks, Global Constraints verbatim. Iterasi kode/test/commit dicatat untuk eksekusi kelak; semua task belum dimulai. Independen task diberi dependency, tidak ada agent dispatch sekarang.

## 10. Factory bootstrap

Dokumen/config/guards sebagian tersedia; docs/factory-readiness.md dan evidence historis memberi rincian. App scaffold, SDK, lockfiles, active project Git hooks, remote CI, exact toolchain dan Firebase belum tersedia. Full gate harus gagal bila app belum ada. Bootstrap aplikasi ditunda secara eksplisit sesuai D-012; T01–T03 menyiapkannya ketika eksekusi diminta. Native/load/restore/release merupakan gate T42–T46. Tidak ada install/deploy pada finalisasi planning.

## 11. Accepted risks

N/A — tidak ada readiness failure yang diminta diterima pengguna sebagai risiko execution. Keputusan baseline contoh diterima D-011; itu bukan waiver test/native/security atau AC-47. Gap tetap tercatat dan kandidat tidak frozen.

## 12. Amendments

| Date | Change | Reason | Approval |
|---|---|---|---|
| 1 Oct 2026 | AM-01 temporary password create-only | Memperjelas serah akun | D-011 |
| 1 Oct 2026 | AM-02 edit kelompok beralasan/referensi immutable | Menjaga audit dan histori | D-011 |
| 1 Oct 2026 | Planning-only boundary | Pengguna meminta cukup planning | D-012 |

Perubahan setelah freeze kelak dicatat dengan AC/screen/contract, alasan dan persetujuan terkait; tidak mengganti frozen facts diam-diam.

## 13. P7 readiness audit kandidat

| Area | Status/evidence |
|---|---|
| Tier/ceremony/spec/constitution/boundaries | Tercatat §1–2, CONSTITUTION |
| Capability/roast/assumptions/premise/clarify | D-007/D-011, R01–21, score10; fakta pilot gate AC47 |
| Brainstorm/design/spec approval | D-007/D-009/D-011; planning-only D-012 |
| Inventory/tokens/mockups/UX |24screens/132states, source docs; baseline260checks, amendemen accepted/render belum dibuktikan |
| Diagrams/interfaces/criteria/drift/completeness | Sources + machine checks; implementation enforcement belum dijalankan |
| Plan/path/interface/constraints |46task registry dan plan; snippets belum dikompilasi |
| Factory bootstrap |Partial; app/toolchain deferred karena D-012; full gate belum PASS |
| User has seen this candidate / freeze for execution |Belum diotorisasi; package diberikan sebagai hasil planning |

**Handoff NOT FROZEN.** Kandidat bisa dibaca ulang saat pengguna meminta eksekusi; tidak perlu mengulang approval spec. SDK/metadata/versi dan bukti yang belum tersedia harus diperiksa, lalu seam execution ditetapkan sesuai scope yang diotorisasi. Planning tidak dianggap aplikasi selesai.
