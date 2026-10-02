# TERNAVA — Operasi lokal, keamanan dan persiapan pilot

1 Oktober 2026 · T2 · baseline yang dimintakan persetujuan melalui spesifikasi.

## Docker lokal

Topologi: `api` (PHP/Laravel runtime), `worker` (image sama, queue), `scheduler` (image sama), `postgres` dan volume private uploads. Queue database pada MVP; worker memiliki failed-jobs dan notification outbox. Tidak diperlukan Redis. Endpoint API bind 127.0.0.1:8080 pada host; database tidak dipublish ke semua interface. Android emulator memakai host bridge yang dibatasi untuk lingkungan development; akses LAN hanya setelah bind/interface/firewall diatur secara eksplisit saat uji perangkat. HTTP development untuk fake data; deployment di luar loopback memakai TLS, APP_DEBUG=false dan CORS tidak terbuka. App mobile memakai environment build, tidak menawarkan pengaturan server bebas kepada operator.

Compose, Dockerfile, migrations dan app scaffold ditulis pada execution setelah handoff; dokumen ini menetapkan rancangan lokal, bukan Docker stack yang sudah berjalan. Tidak ada provider/biaya layanan yang dibeli. Backend health `/health/live` menguji process; `/health/ready` menguji DB/schema dan writable private storage. Worker/scheduler heartbeat dimonitor terpisah; FCM down mengubah status notification degraded, tidak mematikan API record. Endpoint health tidak membocorkan secret/detail host.

Pilot template: satu farm, maksimal 20 kandang, 10 pengguna, 20 perangkat, 20 client sync concurrent; Android min SDK 26 sebagai target rancangan, validasi perangkat calon pilot sebelum membekukan toolchain. Skenario tetap rekaan. Sampel baseline load: 2 vCPU/4 GiB RAM, 100 ribu daily records beserta ledger/revisions, 20 concurrent clients selama 15 menit; p95 read <=500 ms, write <=1 detik, error unexpected <1%, duplicate business effect=0. Semua target memerlukan hasil pengukuran pada implementasi, belum merupakan bukti performa. Jika cakupan calon pilot melewati ini, ubah budget/topologi dan benchmark sebelum migrasi.

## Security review

| Ancaman STRIDE | Pengendalian rancangan | Bukti implementasi sebelum pilot |
|---|---|---|
| Spoofing | Token per perangkat, expiry 7 hari, sandi wajib diganti, rate limit, revoke sesi; offline lease 24 jam | Login brute-force/expiry/reset/revocation, akun bergantian, lease expiry. |
| Tampering | Server policy, validated inputs, version check, immutable ledger, unique ID/key, transaksi | Cross-farm/cage/role tests, parallel writers, altered payload/key, forged attachment parent. |
| Repudiation | Actor+reason+versi+accepted_at pada audit; request_id tanpa credential | Revisi dan ledger dapat ditelusuri, audit append-only oleh app role. |
| Information disclosure | TLS pilot, data perangkat terenkripsi per akun, private uploads, export berizin, redacted logs/push | User B tidak dapat membuka cache/file/export A; backup exclusion dan EXIF test. |
| Denial of service | Pagination limit100, report<=183 hari, 2 MiB foto, throttle, DB pool/timeout, bounded retries | Load dan abuse upload/filter/cursor; tidak ada query tak berbatas. |
| Elevation of privilege | Owner protected, admin hanya kelola operator, authorization pada replay/download dan setiap mutasi | Manipulasi role/cage_ids, reset admin/owner, hidden UI controls diakses langsung melalui API. |

Login: 5 percobaan gagal/menit per username+IP, serta 30/menit per IP; respons generik tidak mengungkap akun. API authenticated default 120/menit per user, upload 10/menit, ekspor 3/menit; Retry-After wajib. Limit configurable server dan diuji, tidak hardcode disable throttle untuk pilot. JSON maksimal 64 KiB; query timeout 5 detik, transaksi maksimal 10 detik. Total koneksi DB backend/workers maksimal 30 (contoh PostgreSQL max_connections=50, ruang untuk admin/backup). Lock wait habis → transient 503, tidak menerima sebagian daily record.

Tidak ada webhook, pembayaran, public signup, URL gambar eksternal, email/SMS atau dynamic HTML yang dieksekusi. API tidak memakai cookie browser; Sanctum bearer mobile. CSRF browser-cookie bukan jalur ini. HTTPS release, HSTS pada domain TLS produksi dan no-sniff pada file response; file disajikan attachment/private. Mobile release tidak menyertakan APP_KEY/service-account FCM/DB password. Runtime secrets melalui file/environment di luar Git, APP_KEY dari runtime Laravel; gitleaks dan scanner fallback memblokir staged secrets/history. Semua dependency/lockfile diaudit, SBOM dan signed APK/backend image digest disimpan saat release. Vulnerability high/critical yang dapat dieksploitasi tidak boleh dibawa ke pilot tanpa perbaikan.

## Data, retensi dan recovery

Baseline review: catatan operasional, ledger, snapshot/audit **730 hari**; foto **180 hari**, inbox **90 hari**, sync changes **30 hari**, logs teredaksi **14 hari**. Penghapusan hanya job berizin yang menjaga referensi/summary; arsip operasional dilakukan satu kelompok lengkap saat tidak aktif, bukan menghapus ledger sebagian. Dedup receipt minimal (key/hash/ACK/tombstone) dipertahankan selama farm masih aktif agar antrean lama tidak membuat efek ulang. Farm closure dan permintaan penghapusan ditangani manual dengan export/konfirmasi owner dan scope tertulis; pengelola akun dapat dinonaktifkan/pseudonymized tanpa mengubah ledger actor ID. Ini keputusan desain untuk review, bukan klaim kepatuhan hukum.

Antrean lokal/draft tidak kedaluwarsa otomatis; pengguna melihat risiko uninstall/hapus data dan diarahkan sync terlebih dulu. Cache accepted yang scope-nya dicabut dibersihkan; payload pending untuk scope tersebut tetap terkunci hingga pengelola memutuskan tindak lanjut. Tidak ada tombol purge all yang merusak antrean tanpa konfirmasi dan export yang berizin.

Backup PostgreSQL+private uploads terenkripsi harian, retensi **30 hari**, satu salinan di luar host runtime sebelum data nyata. Target **RPO <=24 jam**, **RTO <=4 jam**, dibuktikan restore ke environment terpisah termasuk key/secrets yang diperlukan, jumlah record, FK, ledger=saldo, ACL file dan login. Docker volume saja bukan backup. Data yang dihapus dapat bertahan dalam backup sampai rotasi 30 hari; restore harus menerapkan catatan deletion setelah timestamp backup. Rancangan lokal memakai data fiktif dan backup dev dapat dihapus ulang; policy ini berlaku sebelum pilot nyata.

## Reliability dan tanggung jawab

SLO pilot API **99,5% bulanan** untuk request valid pada jendela 24/7; timeout/unexpected5xx dihitung gagal, planned maintenance tetap dihitung. Ukur di server dan external probe; offline pengguna tidak dianggap outage server. Ini target yang akan direview berdasarkan biaya/provider, bukan janji layanan yang telah dicapai.

Metrik: latency/status, queue oldest age, rejected/conflict count agregat, worker/scheduler heartbeat, backup age, failed upload/push, DB/volume capacity. Log JSON dengan request_id/operation_id, endpoint/status/duration, tanpa raw body/sandi/token/foto. Peringatan owner project bila queue tertua>5 menit, heartbeat>3 menit, backup>26 jam, disk>80% atau 5xx>5% selama 5 menit. Primary penanganan adalah pemilik project, secondary admin peternakan; nama orang, kanal kontak, jam respons serta provider/biaya dicatat sebelum pilot. Belum mengirim pesan/alert nyata.

Graceful degradation: FCM down → inbox tersedia; worker down → event tetap durable dengan status delayed; API down → local recording dalam lease; stok belum mutakhir → timestamp jelas dan validasi server saat sync; expired lease → login diperlukan, payload dipertahankan. Runbook saat gagal deploy: pause writer/queue seperlunya, kembali image kompatibel, hindari rollback destructive schema; restore backup hanya setelah owner mengetahui efek kehilangan data dan dedup keys. Jangan otomatis mengulang efek bisnis dengan key baru.

## Gate sebelum data nyata

1. Dapatkan calon farm, validasi total harian/gudang pusat/cohort/role/SOP/perangkat; keputusan yang berbeda mengubah spec/model/preview terkait.
2. Sepakati siapa penanggung jawab, lokasi/provider/biaya, privacy/retensi, serah sandi awal, dan batas pilot. Tidak perlu memilih layanan berbayar untuk menyelesaikan rancangan lokal.
3. Toolchain exact versions/lockfiles, security/contract/concurrency/fault/native accessibility tests, benchmark, signed APK dan SBOM tersedia.
4. Uji operator mengisi/sync/revisi/temuan pada Android nyata, termasuk TalkBack, ukuran teks 200%, target 48 dp, denied notifications, offline/relaunch/account switch. HTML evidence tidak menggantikan hasil ini.
5. Restore dan rollback drill lulus, runbook dan jalur komunikasi tersedia, farm owner menerima kebijakan dan UAT. Distribusi APK pilot terkontrol; Play Store/iOS bukan cakupan tahap ini.
