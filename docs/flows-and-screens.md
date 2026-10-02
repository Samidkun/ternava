# TERNAVA — Flow dan Inventaris Layar

P2.0, 1 Oktober 2026. Scope/stack dan baseline visual diterima untuk lanjut planning (D-007/D-009). Ringkasan AC di sini mengacu pada ID tetap; rumusan EARS dan Verify yang normatif berada dalam spesifikasi P4.

## Tujuan utama dan entry point

Tujuan utama: operator menyimpan catatan harian yang dapat ditelusuri, termasuk saat offline, lalu pemilik menggunakan catatan yang diterima untuk menentukan tindak lanjut.

Entry point: buka aplikasi → sesi valid atau login; push/inbox → objek terkait setelah pemeriksaan akses; tab navigasi → ruang kerja sesuai role. Login pertama dan sinkron referensi pertama membutuhkan koneksi. Splash merupakan transisi singkat aplikasi, bukan halaman marketing/onboarding terpisah.

## Flow sebelum layar

| Flow | Langkah menuju tujuan | Titik gagal dan pemulihan |
|---|---|---|
| F-01 Akses awal | Buka aplikasi → masuk → sinkron referensi → owner setup atau pengguna masuk ruang kerjanya | Kredensial salah: pesan pada form. Offline pertama: masuk kembali saat tersambung. Sesi habis: autentikasi ulang; antrean tidak dibuang. |
| F-02 Persiapan pengelola | Setup peternakan/zona waktu → tambah kandang → tambah kelompok/populasi awal → tambah pengguna/penugasan → buat tugas | Form tidak valid: fokus kolom terkait. Kelompok/kandang duplikat: jelaskan konflik. Tidak berizin: arahkan ke area yang tersedia. Perubahan master membutuhkan koneksi. |
| F-03 Catatan harian | Hari ini → pilih kandang/kelompok → isi total pakan dan telur → periksa kondisi/populasi → simpan → lihat status pengiriman | Isian belum lengkap: simpan draft. Penyimpanan perangkat gagal: isian tetap di form. Offline: catatan menunggu. Konflik/stock/access: tersimpan sebagai perlu ditinjau, bukan sukses server. |
| F-04 Pekerjaan | Hari ini → detail pekerjaan/checklist → catat hasil/kendala → selesai di perangkat → sinkron | Tidak selesai: tetap terbuka dan boleh catat kendala. Akses/tugas berubah: baca penjelasan. Tidak menjanjikan tugas sudah diketahui admin sebelum sync. |
| F-05 Pakan | Pakan → jenis/ledger → penerimaan atau koreksi beralasan → simpan → saldo diterima diperbarui | Penerimaan/koreksi butuh koneksi dan role pengelola. Stok lama diberi timestamp. Pemakaian harian berasal dari F-03, tidak diinput ulang. |
| F-06 Temuan | Buat temuan → detail → pengelola menetapkan petugas → petugas mencatat tindakan → tutup dengan keterangan | Upload foto tertunda tidak menghapus teks; status lampiran jelas. Petugas belum ada: tampilkan perlu penugasan. Objek dihapus/akses dicabut: pemulihan ke daftar. |
| F-07 Monitoring | Ringkasan → kandang belum tercatat/temuan/stok → detail relevan → tindak lanjut | Data belum tersedia bukan nol. Error refresh mempertahankan data terakhir dan timestamp. Tidak ada alert otomatis berbasis ambang medis. |
| F-08 Laporan | Pilih kandang/periode → lihat kelengkapan/data diterima → ekspor CSV | Periode salah: validasi. Belum ada data: arahkan ke pencatatan. Ekspor gagal: coba ulang; tidak menampilkan file seolah sudah dibuat. |
| F-09 Antrean/akun | Buka status kirim → item → coba ulang/perbaiki/masuk ulang → lihat hasil; keluar akun bila diperlukan | Antrean tidak hilang saat jaringan putus/keluar. Konflik tidak ditimpa otomatis. Akun berbeda tidak mendapat antrean akun sebelumnya. |

## Informasi dan navigasi

Operator: tab **Hari ini / Catatan / Temuan / Akun**. Pemilik/admin: tab **Ringkasan / Kandang / Pakan / Akun**. Pengelola mengakses kelompok ayam dari kandang, pengguna dan pengaturan dari akun, serta tugas dari ringkasan. Inbox dan status kirim tersedia di header. Subhalaman memiliki tombol kembali dengan tujuan yang jelas; deep link gagal selalu punya jalan ke ruang kerja.

## Screen inventory

Satu ID = satu file mockup. Bentuk create/edit/read-only adalah state layar yang sama jika pekerjaan utamanya tetap sama. Modal konfirmasi dan picker menjadi state pada layar induk, bukan layar baru. Selain AC pada baris, seluruh layar memakai `AC-25` untuk navigasi/kontrol sesi bersama. `AC-900` khusus alat review state; tidak menjadi fitur aplikasi produksi.

| # | Screen ID | Layar | Archetype | Primary job | Entry | State wajib | AC |
|---|---|---|---|---|---|---|---|
| 1 | `login` | Masuk | Guided Flow | Memulihkan/mendapatkan akses akun | F-01, sesi habis | default, loading, error, offline-first, expired, success | AC-01, AC-900 |
| 2 | `farm-setup` | Pengaturan peternakan | Guided Flow | Menetapkan identitas/zona waktu | F-02, akun | default, loading, error, offline, success | AC-02, AC-900 |
| 3 | `cage-list` | Kandang | List-Detail | Menemukan kandang yang dapat diakses | F-02/F-07, tab | default, empty, loading, error, stale, restricted | AC-03, AC-900 |
| 4 | `cage-form` | Kandang baru/edit | Guided Flow | Menyimpan referensi kandang | F-02, kandang | default, error, offline, success | AC-04, AC-900 |
| 5 | `flock-list` | Kelompok ayam | List-Detail | Menemukan kelompok dan riwayat penempatan | F-02, kandang | default, empty, loading, error, finished | AC-05, AC-900 |
| 6 | `flock-form` | Kelompok baru/edit | Guided Flow | Menyimpan penempatan/populasi awal | F-02, kelompok | default, edit, error, duplicate, offline, success | AC-06, AC-900 |
| 7 | `team-list` | Pengguna dan penugasan | List-Detail | Menemukan pengguna dan cakupan akses | F-02, akun | default, empty, loading, error, restricted | AC-07, AC-900 |
| 8 | `member-form` | Akun/penugasan pengguna | Guided Flow | Menetapkan role dan kandang pengguna | F-02, pengguna | default, edit, error, offline, success, owner-protected | AC-08, AC-900 |
| 9 | `home` | Ringkasan pemilik/admin | Executive Dashboard | Menentukan perhatian berikutnya | F-07, tab | default, empty, loading, error, stale | AC-09, AC-900 |
| 10 | `today` | Hari ini | List-Detail | Memilih pekerjaan/catatan berikutnya | F-03/F-04, tab | default, empty, loading, error, offline | AC-10, AC-900 |
| 11 | `task-form` | Jadwal tugas | Guided Flow | Menetapkan pekerjaan dan petugas | F-02, hari ini | default, error, offline, success | AC-11, AC-900 |
| 12 | `task-detail` | Detail pekerjaan | Guided Flow | Mencatat hasil/kendala pekerjaan | F-04, tugas/inbox | default, missing, error, pending, success | AC-12, AC-900 |
| 13 | `daily-form` | Catatan harian/draft/revisi | Guided Flow | Menyimpan atau meninjau total harian | F-03/F-09, catatan | default, error, offline, local-failure, pending, conflict, read-only, correction, success | AC-13, AC-900 |
| 14 | `daily-history` | Riwayat catatan | Dense Ledger | Menemukan catatan dan statusnya | F-03/F-07, tab | default, empty, loading, error, offline | AC-14, AC-900 |
| 15 | `feed-stock` | Stok dan ledger pakan | Dense Ledger | Memeriksa saldo dan asal perubahannya | F-05/F-07, tab | default, empty, loading, error, stale | AC-15, AC-900 |
| 16 | `feed-entry` | Transaksi pakan | Guided Flow | Mencatat penerimaan/koreksi beralasan | F-05, ledger | default, correction, error, offline, success, large-value | AC-16, AC-900 |
| 17 | `feed-type-form` | Jenis pakan | Guided Flow | Menetapkan jenis dan batas minimum stok | F-05, ledger/transaksi | default, error, offline, success | AC-17, AC-900 |
| 18 | `incident-list` | Temuan | List-Detail | Memilih temuan yang perlu tindak lanjut | F-06/F-07, tab | default, empty, loading, error, offline | AC-18, AC-900 |
| 19 | `incident-form` | Temuan baru | Guided Flow | Menyimpan pengamatan di lapangan | F-06, temuan/catatan | default, error, offline, photo-pending, pending, success | AC-19, AC-900 |
| 20 | `incident-detail` | Tindak lanjut temuan | Guided Flow | Menetapkan/mencatat tindakan berikutnya | F-06, temuan/inbox | default, unassigned, missing, restricted, pending, success | AC-20, AC-900 |
| 21 | `reports` | Laporan operasional | Executive Dashboard | Membaca kelengkapan dan mengekspor periode | F-08, ringkasan | default, empty, loading, error, export-failure, success | AC-21, AC-900 |
| 22 | `inbox` | Pemberitahuan | List-Detail | Membuka pembaruan yang relevan | F-06/F-07, header | default, empty, loading, error, denied | AC-22, AC-900 |
| 23 | `sync-center` | Status pengiriman | List-Detail | Memulihkan catatan yang belum diterima | F-09, header/hasil simpan | default, empty, loading, error, expired, conflict, success | AC-23, AC-900 |
| 24 | `account` | Akun dan pengaturan | Guided Flow | Mengelola sesi dan preferensi akun | F-01/F-09, tab | default, password-required, error, notification-denied, logout-pending, success | AC-24, AC-900 |

## AC provisional

- AC-01: login berhasil menuju area role; gagal/pertama offline/sesi habis punya pemulihan dan tidak membuang antrean.
- AC-02: identitas peternakan dan zona waktu tersimpan melalui alur pengelola.
- AC-03: daftar kandang mengikuti cakupan akses dan status kelengkapan bertanggal.
- AC-04: kandang valid dapat disimpan; duplikasi atau akses gagal terlihat.
- AC-05: kelompok ditautkan ke kandang, dengan status/riwayat penempatan yang jelas.
- AC-06: populasi awal dan tanggal penempatan valid; referensi aktif yang bentrok tidak ditimpa diam-diam.
- AC-07: pengguna/penugasan dapat ditemukan oleh pengelola yang berizin.
- AC-08: role dan cakupan kandang disimpan; operator tidak mengatur akses; owner pertama tidak dinonaktifkan melalui alur ini.
- AC-09: ringkasan membedakan belum dicatat, data diterima, dan data kedaluwarsa; perhatian menuju objeknya.
- AC-10: operator memilih pekerjaan/catatan kandang yang ditugaskan, termasuk dengan referensi offline yang tersedia.
- AC-11: pengelola menetapkan tugas/petugas/tanggal/SOP tanpa jadwal medis otomatis.
- AC-12: hasil tugas tersimpan lokal sebelum pengiriman; kendala dan status terlihat.
- AC-13: pakan kg/telur butir dan perubahan yang dicatat disimpan dengan tanggal/kelompok; draft, antrean, konflik, dan revisi tidak hilang/tergandakan.
- AC-14: riwayat dapat difilter tanggal/kandang dan dibuka untuk review sesuai izin.
- AC-15: saldo/ledger/waktu pembaruan dapat ditelusuri; pemakaian harian tidak dicatat dua kali.
- AC-16: penerimaan atau koreksi beralasan valid memperbarui saldo setelah diterima server.
- AC-17: jenis pakan/batas minimum dapat disimpan pengelola tanpa mengganti histori transaksi.
- AC-18: temuan dapat ditemukan melalui status/kandang dan dibuka sesuai izin.
- AC-19: pengamatan teks tetap tersimpan saat offline atau foto menunggu.
- AC-20: penanggung jawab, tindakan, status, dan riwayat diperbarui sesuai role; penutupan butuh keterangan.
- AC-21: laporan periode memuat kelengkapan data diterima dan ekspor yang tidak mengklaim berhasil saat gagal.
- AC-22: inbox menuju objek dengan izin; objek tidak tersedia/akses berubah punya jalan kembali.
- AC-23: antrean/penolakan/sesi habis terlihat; retry payload sama menjaga identitas; perbaikan tidak menimpa versi server diam-diam.
- AC-24: penggantian sandi, preferensi pemberitahuan, dan keluar dengan antrean tertunda memiliki umpan balik; pergantian akun tidak membocorkan data lokal.
- AC-25: navigasi bersama, kembali, inbox/status kirim, dan konfirmasi isian belum tersimpan menghubungkan layar sesuai role serta memberi jalan pemulihan yang jelas.
- AC-900: reviewer dapat memilih state simulasi dan memahami bahwa data/hasil aksi preview adalah contoh; kontrol ini tidak ditransplantasi ke Flutter.

## Sanity check dan pengecualian

Semua flow tercakup oleh entry pada tabel; tidak ada layar tanpa asal. Setiap layar punya satu pekerjaan utama. Status read-only/revisi dan modal logout merupakan bagian alur pekerjaan, bukan halaman dekoratif. Tugas vaksinasi memakai `task-form`/`task-detail`; tidak ada modul medis baru.

Dikecualikan: landing marketing, carousel onboarding, pendaftaran publik, dashboard web, identitas setiap ayam, grafik sensor, transfer gudang, akuntansi penuh, tema gelap, PDF, dan chat. Splash/loading serta error objek/server/offline ditangani pada layar terkait, bukan halaman web 404/500. SEO/favicon/OG/sitemap tidak berlaku pada aplikasi native; ikon launcher Android ditetapkan pada persiapan implementasi.

## Batas preview

Mockup HTML adalah alat review visual/alur, bukan aplikasi Flutter atau backend berjalan. Perubahan contoh di satu file tidak menjadi transaksi file lain. Offline, izin, konflik, dan push disimulasikan; ketahanannya baru dibuktikan lewat pengujian implementasi. Pengujian preview memeriksa reachability, status, layout, dan interaksi contoh, bukan keamanan server.
