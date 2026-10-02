# TERNAVA — Kontrak API dan sinkronisasi

1 Oktober 2026 · normatif bersama `contracts/openapi.json` dan spesifikasi P4; belum ada server berjalan.

## Bentuk umum

Base `/api/v1`. JSON memakai snake_case. Detail berupa `{data: object}`, list berupa `{data: [], meta: {next_cursor, has_more, as_of}}`. Cursor keyset opaque, limit default 50/maksimum 100. Filter periode inklusif tanggal farm; rentang report maksimal 183 hari dan cakupan rancangan 20 kandang. Nilai pakan kg dan IDR berupa string fixed dua desimal, tidak JSON float. SQL DECIMAL(14,2) untuk kg dan DECIMAL(18,2) untuk IDR; Dart scaled integers/BigInt. Total pembelian = kg × harga/kg, pembulatan half-up dua desimal; overflow ditolak 422. Telur/mortalitas/populasi adalah integer nonnegatif dengan batas dalam schema. Input `"0.00"` sah; null berarti belum diamati pada field opsional.

Semua mutasi bisnis yang menghasilkan ACK membawa `Idempotency-Key` UUID. Aksi auth/registrasi push memakai perilaku endpointnya sendiri. ACK berisi operation_id (key), resource_id, resource_version, accepted_at. Client mengambil detail atau delta sesudah ACK; angka terbaru tidak disimpulkan dari request bila versi server berbeda. Metadata cursor dan resource_version bukan nilai yang boleh ditebak UI.

Error memiliki `error.code/message/fields/request_id/retryable/current_version` sesuai schema. Response 400 untuk request/cursor rusak, 401 token hilang/habis, 403 akses atau ganti sandi wajib, 404 objek di luar cakupan atau tidak ada, 409 bentrok, 422 invalid bisnis, 429 limit, 500/503 gangguan. 404 atas objek di luar cakupan mencegah enumerasi; endpoint role yang dilarang boleh 403. Respons error tidak memuat token, stacktrace, atau data akun lain.

| Kode utama | Hasil bagi client |
|---|---|
| AUTH_REQUIRED / SESSION_EXPIRED | Hentikan sync; minta login; simpan partisi antrean. |
| PASSWORD_CHANGE_REQUIRED | Hanya session/change-password/logout; akun menuju ganti sandi. |
| ACCESS_REVOKED | Hentikan operasi; kunci cache yang kehilangan akses, simpan payload antrean terkunci. |
| VERSION_CONFLICT / DAILY_ALREADY_EXISTS | Ambil versi server untuk review; tidak sum/overwrite. |
| IDEMPOTENCY_KEY_REUSED | Key sama dengan isi berbeda ditolak; perlu investigasi intent, tidak auto retry key baru. |
| CURSOR_RESET_REQUIRED | Bootstrap ulang snapshot diterima; draft/outbox tidak dihapus. |
| INSUFFICIENT_STOCK / INVALID_POPULATION | Tidak ada sebagian data diterima; payload lokal dapat diperbaiki. |
| VALIDATION_FAILED | Tampilkan pesan field; perbaikan menjadi intent baru dengan key baru. |

## Sesi, izin dan akses offline

Login online memberikan bearer token Sanctum untuk device_id, berlaku **7 hari** secara eksplisit. Sanctum default tidak menghapus masa berlaku sendiri; konfigurasi expiry dan pruning diperlukan ([dokumentasi](https://laravel.com/framework/docs/13.x/sanctum)). Tidak ada refresh-token OAuth yang diasumsikan. Reauth diperlukan setelah expiry; token baru tidak mengubah identitas key idempotensi lama.

Login pertama dan ganti akun memerlukan koneksi. Sandi sementara minimal 12 karakter, hash Argon2id di server, harus diganti sebelum akses operasi. Username unik case-insensitive, sandi tidak dicatat/logged/di-cache. Admin hanya mengelola operator; owner mengelola admin/operator. Akun owner pertama tidak dapat diturunkan atau dinonaktifkan melalui API MVP. Reset oleh pengelola berizin mencabut sesi target; perubahan sandi mencabut semua sesi termasuk sesi saat ini, lalu login ulang. Tidak ada kirim sandi lewat aplikasi lain/email/SMS.

Setiap request memeriksa user aktif, membership, farm dan cage; hasil tugas oleh petugas yang ditugaskan atau owner/admin, tindakan temuan oleh assignee atau owner/admin. Operator dapat membaca referensi pakan/saldo untuk pencatatan, tetapi tidak ledger pembelian, pengelolaan pengguna, atau report pengelola. Auth check dilakukan juga sebelum replay idempotensi atau download file.

Offline lease **24 jam** sejak validasi sesi server terakhir. Dalam lease, sesi perangkat yang belum logout dapat memakai cache/catatan lokal; tidak memperpanjang lease hanya dengan membuka app atau gagal request. Reboot memakai trusted server offset yang dipersist; rollback jam lokal terhadap observasi terakhir mengunci akses sampai validasi online. Ini bukan bukti kebal manipulasi perangkat. Revokasi tidak bisa diketahui seketika saat perangkat putus jaringan; saat online 401/403 atau scope berubah, cache terkait terkunci/dibersihkan, antrean tetap terisolasi. Setelah lease habis, login online diperlukan sebelum membuka/menulis data farm.

## Penyimpanan lokal dan state machine

Partisi actor_id+farm_id, key AES-256-GCM melalui library yang dipelihara dan platform secure storage. Nonce baru tiap enkripsi, associated data mengikat actor/farm/object/schema version. Private photos dienkripsi. Token dan key tidak berada dalam plaintext SQLite/SharedPreferences/log. Android backup tidak menyertakan token, key, database atau foto lokal. Perangkat hilang/uninstall/hapus data app bukan skenario recovery draft yang dijanjikan; UI sync-center mengingatkan untuk mengirim antrean sebelum tindakan itu.

`draft` → transaksi lokal `pending` (payload immutable+operation_id) → `sending` → `accepted`; atau `needs_review`, `blocked_auth`. Status sending kembali pending setelah relaunch/timeout. Hanya ACK server setelah commit menghasilkan “Diterima sistem”. Tombol simpan sukses lokal menyebut tersimpan di perangkat/menunggu kirim. Error storage mempertahankan form dan tidak menampilkan sukses. Tidak menutup form dengan asumsi transaksi pasti tersimpan.

Simpan draft boleh tidak lengkap, tetapi kirim harian membutuhkan tanggal, kelompok, jenis pakan, kg dan telur eksplisit. Catatan pending tidak diedit. Rejected payload dapat disalin untuk perbaikan memakai key baru; versi lama tetap tersedia. Konflik ketika operator lain sudah mencatat hari yang sama tidak dapat diubah menjadi request create baru diam-diam.

Foreground worker dan tombol “Coba kirim lagi” memproses satu operasi per partisi berurutan sesuai dependensi. Background sync Android adalah best effort. Timeout jaringan 20 detik; retry transient 5xx/timeout exponential jitter mulai 2 detik sampai maksimum 5 menit. 429 mematuhi Retry-After; 401/403 menghentikan pengiriman; 409/422 menunggu review. Maksimal 5 retry otomatis per sesi foreground, lalu aksi manual; payload tidak kedaluwarsa otomatis. Perubahan master online memiliki key/payload tersimpan sampai diketahui hasilnya, sehingga timeout dapat dipulihkan tanpa create duplikat.

## Idempotensi dan atomic daily

Namespace key adalah (farm, actor, operation_id), bukan token perangkat. Hash canonical JSON (urutan key stabil, tipe/nilai sama) + method + canonical path disimpan. Multipart hash menggunakan field metadata dan hash file. Duplicate key/same hash setelah pemeriksaan izin mengembalikan ACK asli; duplicate key/different hash 409. Request concurrent same-key hanya boleh memiliki satu business effect. Business rejection tidak membuat receipt sukses. Client tidak mengubah key untuk menyelesaikan timeout yang belum diketahui hasilnya.

Global lock order: counter sync farm → flock(s UUID urut) → daily/task/incident row → saldo pakan (UUID urut) → receipt. Saat replay selesai ditemukan sebelum transaksi, ACK dapat dibaca tanpa lock setelah auth; jika race, recheck setelah counter lock. Counter farm memastikan sequence hanya terbuka sesuai urutan commit. Jangan memakai BIGSERIAL sendiri sebagai cursor commit karena transaksi yang terlambat dapat membuat perubahan terlewat.

Satu harian unik (farm, flock, business_date), total penuh dan tidak dijumlahkan antaroperator. Semua efek berikut satu transaksi: daily+snapshot versi, ledger pakan, saldo, population entry/projection, audit, receipt, sync change dan notification event. Jika satu validasi gagal, semuanya rollback. Error tak terduga sebelum ACK dapat diretry dengan key yang sama. Database deadlock/serialization failure diretry maksimal 3 kali di server; habis → 503 tanpa klaim sukses.

Revisi owner/admin mengirim full replacement fields, base_version dan alasan. Flock/date tetap. Saldo pakan dihitung dengan reversal pemakaian lama dan pemakaian baru; ledger lama immutable. Revisi beda jenis pakan mengunci kedua saldo menurut UUID. Saldo negatif atau overflow menolak semua perubahan. Operator tidak merevisi accepted record. Jenis pakan yang telah nonaktif tetap boleh direversal; pemakaian baru nonzero pada jenis nonaktif ditolak.

## Populasi, pakan dan tugas

Status Selesai dengan finished_on=null menggunakan tanggal farm saat request diterima, yang ditampilkan saat konfirmasi; Aktif membutuhkan finished_on=null. Create memakai status form. Satu flock per kandang pada setiap tanggal; rentang penempatan inklusif tidak overlap. Populasi awal positif. Setelah transaksi operasional pertama, populasi awal/placed_on/cage tidak dapat diedit; perubahan populasi melalui catatan harian dengan histori. Kelompok selesai tetap menerima catatan terlambat/revisi untuk tanggal dalam rentangnya, maksimal 30 hari dari tanggal farm hari ini. Tanggal masa depan ditolak; anggota yang kehilangan assignment tidak dapat mengirim catatan lama tanpa akses kini.

Mortalitas null belum dicatat; nol eksplisit berarti sudah dicatat nol. Population_change null belum diperiksa; none membutuhkan count=0, in/out count>0 dan asal/tujuan. Delta = masuk − keluar − mortalitas yang dicatat. Prefix populasi setiap tanggal (dari populasi awal) tidak boleh negatif setelah catatan terlambat/revisi. Tidak menyimpulkan seluruh populasi sehat dari data kosong. Pemindahan antarflock tidak otomatis diselesaikan di kedua kelompok; input masuk/keluar terpisah disertai catatan pengelola, tanpa fitur transfer stok/ternak baru.

Gudang pusat, jenis pakan memiliki saldo diterima. Opening sekali per jenis sebelum pemakaian, alasan pemeriksaan fisik wajib; receipt arah in, kg>0, harga>0 dan supplier wajib. Adjustment in/out, kg>0, alasan wajib, harga/supplier null. Untuk opening, arah in, kg boleh 0. Daily kg=0 tidak membuat ledger usage nol; masih perlu jenis pakan yang ada. Tidak mengedit transaksi ledger lama: selisih diperbaiki adjustment beralasan. Stok memakai urutan transaksi diterima; tanggal bisnis dicatat tetapi tidak menjanjikan saldo historis atau valuasi akuntansi.

Tugas once/daily/weekly, tanggal dan local_time memakai zona farm. Weekly jatuh pada hari yang sama dengan start_on. Checklist dibuat literal dari baris SOP nonkosong (maksimal 20), satu label per baris, tanpa interpretasi medis. Occurrence menyimpan item ID/label; hasil menyimpan checked untuk setiap item. Item belum dicentang boleh dicatat sebagai kendala; complete tidak otomatis mencentang semuanya. Maksimal satu occurrence/template/tanggal; scheduler mematerialisasi 7 hari ke depan dan creation langsung menyiapkan window tersebut. Template berubah hanya mengubah occurrence belum memiliki hasil; completed tetap snapshot lama. Hasil mencatat note (tetap open) atau completed; base_version run mencegah hasil stale. Tugas dibatalkan/penugasan berubah menolak hasil lama dengan konflik. Jenis vaccination/inspection hanya label+SOP dari pengelola; tidak menentukan dosis, diagnosis atau jadwal otomatis.

Temuan bersifat manual: observation/attention routine atau priority, belum ditugaskan terlihat. Assignment dan action memakai base_version, setiap perubahan memiliki actor/history. Penutupan membutuhkan notes. Temuan closed tidak dibuka ulang pada MVP; pengamatan baru membuat temuan baru. Condition finding di catatan harian merupakan perhatian yang ditautkan ke catatan; tidak otomatis membuat duplikat temuan. Photo upload sesudah parent ACK, maksimal 3 JPEG/PNG per parent, 2 MiB per foto; validasi bytes/hash, hapus EXIF, private path, download berizin. Gagal foto tidak membatalkan teks yang diterima.

## Pull sync, laporan dan notifikasi

Bootstrap mematok high-watermark dan scope_version pada halaman pertama; snapshot dari revisions pada watermark itu, termasuk cache task/inbox hanya yang berizin. Lease snapshot 15 menit, expired → reset. Delta setelah halaman terakhir mulai pada watermark sama, sehingga mutasi selama bootstrap tidak hilang. Halaman dan cursor disimpan atomik lokal. Cursor mengikat farm/actor/scope; retensi delta 30 hari. Cursor kedaluwarsa/akses berubah → bootstrap, tidak menghapus draft/outbox. `remove` value=null; `upsert` value bertipe sesuai resource_type. FeedBalance resource_id memakai feed_type_id. Snapshot bootstrap dan perubahan sync tidak berisi password, token, supplier untuk operator, atau anggota lain.

Report memakai transaksi snapshot konsisten accepted data. Expected records = pasangan flock aktif/tanggal dalam rentang, termasuk flock selesai pada tanggal penempatan historis. Missing menghasilkan field jumlah null dan status missing; total seluruhnya kosong → null, jumlah nol dari catatan accepted → 0. Accepted/expected memberi kelengkapan; bukan kesehatan/estimasi populasi tak diperiksa. As_of/waktu UTC dan timezone disertakan; periode harian/mingguan/bulanan merupakan preset UI untuk from/to inklusif. Report maksimal 183 hari; request lebih panjang ditolak dengan cara mempersempit periode. Cache report offline diberi as_of dan status stale; ekspor membutuhkan jaringan, menggunakan snapshot saat request export (timestamp-nya dapat berbeda dari preview terakhir). CSV UTF-8, escape delimiter/quote/newline dan neutralisasi cell text diawali =,+,-,@ untuk mencegah spreadsheet formula injection; akses sama dengan report. Tidak menghitung laba dari harga pakan.

Notification event dibuat dalam transaksi bisnis; worker dedup inbox per event/penerima. Peristiwa: tugas mendekati jadwal, temuan baru/assignment/tindakan, harian diterima, saldo melewati minimum. Alert stok hanya saat transisi melewati batas, kembali normal reset, bukan spam setiap refresh. Push memuat reference ID dan teks umum, download objek tetap auth check. Retry push maksimal 5 (jitter hingga 15 menit), inbox tidak dibatalkan bila FCM gagal. Menolak izin push masih memungkinkan inbox; tidak menjanjikan push real-time saat perangkat offline. [FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started) membutuhkan konfigurasi proyek Firebase pada implementasi/pilot.
