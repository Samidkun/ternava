# TERNAVA — Arsitektur dan batas tanggung jawab

1 Oktober 2026 · T2 · L · spec-anchored · rancangan untuk review spesifikasi.

## Sistem

Satu aplikasi Android Flutter, satu Laravel REST API, satu PostgreSQL, satu worker dan scheduler dari image backend yang sama. Backend dikembangkan lewat Docker lokal; FCM opsional untuk pengiriman push, inbox tetap tersedia tanpa FCM. Tidak ada frontend web, microservice, Redis, sensor, atau AI pada scope ini.

| Batas | Tanggung jawab | Kontrak / pengujian yang mengikat |
|---|---|---|
| View → ViewModel | Widget mengirim intent; ViewModel menyajikan immutable state: loading/data/empty/error, local status, field errors. Routing memakai screen ID dan parameter resource, bukan nama contoh kandang. | Widget tests untuk seluruh inventory/state; typed commands di mobile, assertions navigasi/izin. |
| ViewModel → Repository | Satu sumber state layar. Repository menggabungkan snapshot diterima dengan status draft/outbox tanpa menjumlahkan total harian keduanya. | API internal Dart yang diuji lewat fake storage/network; persistence integration tests. |
| Repository → LocalService | Drift/SQLite menyimpan partisi pengguna, ciphertext draft/cache, outbox immutable, foto terenkripsi dan checkpoint. Satu transaksi untuk draft+outbox, ACK+cache, atau delta+cursor. | `contracts/schema.json.local_store`; crash/relaunch tests pada perangkat, bukan simulasi HTML. |
| Repository → ApiService | Serialisasi field dari OpenAPI; bearer token; timeout, uniform errors dan retry sesuai `api-sync.md`. ApiService tidak mengubah state widget. | `contracts/openapi.json`, `examples.json`; response fixtures dan negative contract tests pada Dart/Laravel. |
| Route → Policy/FormRequest → UseCase | Controller tipis. Policy memeriksa sesi/farm/role/kandang, FormRequest memeriksa bentuk, use case memeriksa aturan bisnis dan transaksi. Eloquent hanya melalui use case untuk mutasi kritis. | API integration pada PostgreSQL, termasuk akses silang, unique constraint, stok/populasi, optimistic version. |
| UseCase → PostgreSQL/outbox | Commit receipt idempotensi, record/snapshot, ledger/saldo, audit, perubahan sync dan notification event bersama. Pengiriman FCM di luar transaksi. | Schema logis + migration constraints + transaksi concurrency/fault tests. |
| Worker → Inbox/FCM | Event diproses setidaknya sekali; inbox unik per event/penerima, push berisi ID objek dan teks umum. Retry tidak menggandakan inbox. | Duplicate-job test, denied push/offline FCM test. |

MVVM menggunakan ViewModel `ChangeNotifier`/`Listenable`, constructor injection dan repository per kapabilitas. Domain use case hanya untuk penyimpanan/sync/revisi yang memiliki beberapa langkah; tidak membuat abstraksi untuk setiap getter. Flutter guidance mendukung pemisahan repository dari layanan lokal/remote: [offline-first](https://docs.flutter.dev/app-architecture/design-patterns/offline-first).

## Modul

| ID | Pemilik data/aksi | Dependensi bisnis |
|---|---|---|
| `farm-access` | farm, akun/role/penugasan, sesi, kebijakan akses, receipt/sync/audit infrastructure | — |
| `flocks` | kandang, kelompok, penempatan dan proyeksi populasi | farm-access |
| `feed-ledger` | jenis pakan, ledger immutable, saldo gudang pusat | farm-access, flocks |
| `daily-operations` | total harian, versi/revisi, tugas/SOP, hasil dan lampiran | farm-access, flocks, feed-ledger |
| `incidents` | temuan, assignment, tindakan dan status | farm-access, flocks, daily-operations |
| `insights` | ringkasan/laporan dan pemberitahuan dari event | seluruh modul sebelumnya |

Use case daily mengorkestrasi service feed dan flock; feed tidak memanggil use case daily. Foreign key ke catatan merupakan referensi asal ledger, bukan dependensi service melingkar. Sync/storage/security merupakan infrastructure lintas modul; worker insights tidak menjadi syarat commit operasional.

## Data, runtime dan perubahan

Schema logis memuat 26 tabel bisnis/infrastruktur. Tabel framework Laravel untuk queue/failed jobs/migrations ditambahkan saat scaffold, bukan disembunyikan sebagai model bisnis. Sanctum menggunakan tabel token framework dengan metadata perangkat; `device_sessions` adalah representasi logis, tidak membuat validator token kedua.

Username dan kode master memakai unique index ekspresi lower() yang tercatat di schema; opening pakan, active flock dan owner memakai partial unique index. FK sederhana dilengkapi validasi farm pada service dan constraint komposit ketika memungkinkan. Semua ID resource client memakai UUID v4. Timestamp kejadian/commit UTC, tanggal bisnis berdasarkan zona waktu IANA farm. Zona waktu tidak dapat diubah setelah catatan/jadwal operasional pertama; kode/identitas kelompok dan tanggal catatan tidak dipindahkan lewat revisi.

Laravel **13**, PHP **8.4**, PostgreSQL **18** merupakan keluarga runtime rancangan. Laravel 13 mendukung PHP 8.3–8.5 menurut [release notes resmi](https://laravel.com/framework/docs/13.x/releases). Versi patch Flutter stable, Dart, plugin, Composer packages dan digest image dicatat dalam toolchain manifest/lockfile sebelum feature code. Tidak ada klaim bahwa versi patch terbaru telah dipasang. Drift menyediakan [transaksi lokal](https://drift.simonbinder.eu/dart_api/transactions/); transaksi remote tetap berbeda dan membutuhkan protocol ACK.

Perubahan kontrak/schema memperbarui diagram dan fixtures dalam perubahan yang sama. Implementasi memakai migration maju (expand → backfill → switch → contract); jangan menjalankan destructive down migration atas data pilot. Client API v1 tetap diterima selama pilot; perubahan breaking memerlukan v2 dan prosedur upgrade yang menjaga antrean lama.

Diagram di `docs/diagrams/` dihasilkan dari sumber JSON; `python3 scripts/generate_diagrams.py --check` mendeteksi drift. `scripts/check_contracts.py` memeriksa referensi, mapping layar/AC, contoh dan subset schema yang dipakai. Full OpenAPI semantic validator, generated/typed Dart DTO dan contract tests response nyata menjadi gate implementasi, bukan hasil yang diklaim dari pemeriksaan dokumen.
