# TERNAVA — Rancangan Scope dan Alur untuk Review

Tanggal: 1 Oktober 2026. Status: rancangan P0/P1, belum spesifikasi final, belum rencana implementasi, belum handoff yang dibekukan.

Update review: arah scope/stack diterima pengguna pada 1 Oktober 2026 melalui “sip,bagus,lanjutin planning nya”. Planning telah berlanjut ke flow/inventaris layar, ruling desain, token, dan mockup. Detail visual/aturan baru menunggu review; lihat `decisions.md`, `planning-rulings.md`, dan `flows-and-screens.md`.

Root project: `/mnt/data/porto/ternava`.

## Keputusan yang sudah tersedia

Nama TERNAVA, komoditas ayam petelur, target MVP mobile dengan backend untuk uji coba peternakan, serta mobile Flutter telah dipilih pengguna. Planning mengikuti web-app-sop, tier T2, ceremony L, dan spec-anchored.

## Hasil yang dituju

Operator dapat menyelesaikan pencatatan harian kandang saat koneksi terputus. Catatan yang tersinkron memperbarui produksi, penggunaan pakan, pekerjaan, dan temuan tanpa menggandakan transaksi. Pemilik melihat kondisi yang membutuhkan tindakan serta kelengkapan data hari tersebut.

## Pendekatan yang dibandingkan

| Pendekatan | Manfaat | Tradeoff | Posisi |
|---|---|---|---|
| Operasional harian dengan input manual dan sinkronisasi offline | Menghubungkan operator, stok, produksi, dan tindak lanjut tanpa menunggu pengadaan sensor | Sinkronisasi dan koreksi angka perlu dirancang teliti | Rekomendasi untuk MVP yang diminta |
| Pakan dan produksi sebagai pilot lebih sempit | Menguji dua pencatatan terpenting pada satu alur yang lebih kecil | Penugasan dan tindak lanjut kesehatan menjadi perluasan berikutnya | Alternatif jika kapasitas atau waktu pilot terbatas |
| Monitoring berbasis sensor sejak pilot | Pembacaan lingkungan dapat masuk dari perangkat | Memerlukan perangkat, pemasangan, kalibrasi, dan dukungan lapangan yang belum diketahui | Pengembangan setelah kebutuhan perangkat terbukti |

## Scope yang diusulkan

1. **Peternakan dan akses:** satu peternakan pilot, beberapa kandang, owner/admin/operator, penugasan kandang, login, dan pengaturan akun.
2. **Kelompok ayam:** identitas kelompok, kandang, tanggal penempatan, populasi awal, dan status aktif/selesai. Pencatatan agregat mengikuti kelompok; tidak mengasumsikan identitas setiap ayam.
3. **Pekerjaan harian:** jadwal dan checklist sesuai SOP peternakan, status selesai, serta kendala yang dilaporkan.
4. **Catatan harian:** tanggal, kelompok/kandang, pakan dipakai dalam kg, produksi telur dalam butir, kondisi yang diamati, kematian atau perubahan populasi yang benar-benar dicatat, serta keterangan/foto bila diperlukan.
5. **Pakan:** jenis pakan, penerimaan, harga pembelian, penggunaan, koreksi beralasan, saldo, dan batas minimum yang ditetapkan admin.
6. **Temuan:** pelaporan kondisi, tingkat perhatian yang dipilih pelapor, penanggung jawab, status, tindakan, dan riwayat. Jadwal pemeriksaan/vaksinasi dimasukkan pengelola berdasarkan SOP yang digunakan.
7. **Monitoring dan laporan:** kelengkapan catatan per tanggal/kandang, tugas belum selesai, temuan terbuka, stok rendah, produksi telur, serta laporan periode yang dapat dibagikan.
8. **Offline dan pemberitahuan:** cache yang tersedia setelah login/sinkron awal, catatan lokal, antrean pengiriman, status terkirim/menunggu/perlu diperbaiki, inbox, dan push setelah data diterima backend.

Pengembangan lanjutan yang diusulkan: sensor IoT, beberapa peternakan per akun, akuntansi usaha lengkap, model lintas komoditas, analisis berbasis AI, dan dashboard web tersendiri. Alasan penempatannya setelah MVP adalah memusatkan pilot pada pencatatan lapangan dan penggunaan datanya.

## Peta kapabilitas

Peta ini masih diusulkan. ID dipertahankan ketika scope disetujui agar konsisten pada spesifikasi dan tugas berikutnya.

| Module ID | Tanggung jawab | Depends on |
|---|---|---|
| `farm-access` | Identitas peternakan, akun, role, kandang, dan penugasan | — |
| `flocks` | Data kelompok ayam dan penempatan sebagai referensi operasional | `farm-access` |
| `feed-ledger` | Stok dan transaksi pakan yang dapat ditelusuri | `farm-access`, `flocks` |
| `daily-operations` | Tugas, catatan produksi/kondisi/populasi harian, serta koordinasi pemakaian pakan | `farm-access`, `flocks`, `feed-ledger` |
| `incidents` | Temuan, penanggung jawab, dan tindak lanjut | `farm-access`, `flocks`, `daily-operations` |
| `insights` | Dashboard, laporan, inbox, dan aturan pemberitahuan dari data tersimpan | `farm-access`, `flocks`, `feed-ledger`, `daily-operations`, `incidents` |

Urutan kapabilitas: `farm-access` → `flocks` → `feed-ledger` → `daily-operations` → `incidents` → `insights`.

Penyimpanan lokal dan sinkronisasi merupakan mekanisme bersama pada mobile/backend. Mereka dirancang bersama kontrak setiap kapabilitas, bukan module bisnis terpisah yang menyebabkan dependensi berputar. `flocks` mengelola referensi kelompok; agregasi populasi dari catatan dibuat pada `insights` agar tidak mengharuskan dependensi balik.

## Peran dan izin yang diusulkan

| Aksi | Owner | Admin | Operator |
|---|---|---|---|
| Melihat seluruh kandang dan laporan | Ya | Ya | Hanya kandang yang ditugaskan |
| Mengatur peternakan dan role | Ya | Tidak mengubah owner | Tidak |
| Mengatur kelompok, jadwal, dan penugasan | Ya | Ya | Tidak |
| Mencatat pekerjaan, produksi, pemakaian pakan, dan temuan | Ya | Ya | Pada kandang yang ditugaskan |
| Menerima pakan dan mengesahkan koreksi stok | Ya | Ya | Tidak |
| Menetapkan penanggung jawab temuan | Ya | Ya | Tidak |
| Mencatat tindakan pada temuan | Ya | Ya | Jika ditugaskan |

Pencatat dapat memperbaiki draft lokal sebelum dikirim. Koreksi atas catatan yang telah diterima backend harus menyimpan alasan dan revisi. Izin serta proses review koreksi akan dirinci setelah alur pengguna disetujui.

## Alur pengguna

**Owner/admin:** masuk → setup peternakan, kandang, kelompok, dan pengguna → menetapkan jadwal/penugasan → membaca kelengkapan catatan dan temuan → menentukan tindak lanjut → memeriksa laporan.

**Operator:** masuk dan melakukan sinkron awal → membuka pekerjaan hari ini → memilih kandang/kelompok → mengisi catatan → menyimpan di perangkat → melihat status pengiriman → menindaklanjuti temuan yang ditugaskan → mencatat penyelesaian.

**Dari pemberitahuan:** buka item → lihat detail temuan/tugas → periksa akses → lakukan tindakan yang tersedia. Jika akses sudah dicabut atau item tidak tersedia, tampilkan penjelasan dan jalan kembali ke halaman yang dapat diakses.

**Saat jaringan putus:** data yang telah tersedia tetap bisa dibaca; catatan baru disimpan lokal. Jika data referensi belum tersedia, pengguna diberi penjelasan bahwa sinkron awal diperlukan. Penyimpanan lokal gagal harus terlihat dan isian tetap dipertahankan.

**Saat kembali online:** antrean dikirim menggunakan identitas aksi yang tetap. Backend mengakui hasil atau memberi alasan penolakan. Catatan yang ditolak karena versi, akses, atau stok memerlukan tindakan yang jelas dan tidak hilang diam-diam.

## Rancangan arsitektur

- Mobile Flutter mengelola UI, penyimpanan lokal SQLite melalui kandidat Drift, dan antrean perubahan.
- Laravel REST API dengan Sanctum yang diusulkan mengelola autentikasi, otorisasi, validasi domain, transaksi, serta sinkronisasi. Izin role dan akses kandang diperiksa backend pada setiap operasi.
- PostgreSQL menyimpan data yang telah diterima backend, ledger, revisi, dan hasil idempotensi.
- Penyimpanan foto bersifat privat; pengambilan file mengikuti akses peternakan/kandang.
- Antrean backend menangani laporan dan pemberitahuan setelah transaksi berhasil. Riwayat inbox tetap tersedia ketika push terlambat atau tidak diterima perangkat.

Pemilihan Drift, Laravel, PostgreSQL, dan FCM masih bagian dari usulan yang direview. Versi serta konfigurasi dikunci setelah scope, perangkat pilot, dan desain visual jelas.

## Keputusan data yang perlu diuji pada pilot

- Catatan harian dibatasi satu per kelompok/tanggal lokal sebagai default proposal. Jika peternakan mencatat tiap pengumpulan telur, model diubah menjadi event pengumpulan sebelum kontrak final ditulis.
- Pakan pada form harian dan stok memakai satu asal transaksi; pengguna tidak perlu menginput pemakaian yang sama dua kali.
- Koreksi catatan tidak menghapus histori. Dampaknya pada stok memakai transaksi koreksi yang dapat ditelusuri.
- Harga pembelian membantu membaca biaya pakan yang tercatat; ringkasan ini tidak digunakan sebagai laba usaha.
- Angka kosong berarti belum dicatat. Angka nol hanya digunakan ketika pengguna benar-benar mencatat nol.
- Snapshot stok pada perangkat menampilkan waktu pembaruan. Validasi backend diperlukan sebelum nilai dianggap saldo yang diterima sistem.
- Satu peternakan dipakai pada pilot, tetapi akses data tetap memiliki identitas peternakan agar data antar akun tidak bercampur.

## Risiko yang paling memengaruhi desain

Pengiriman ganda, catatan harian bersamaan, pakan yang tidak sesuai stok fisik, isian yang terlalu panjang, perangkat/koneksi yang berbeda dari asumsi, dan temuan yang tidak punya penanggung jawab. Tindakan mitigasi dirangkum pada dokumen pre-mortem.

## Urutan planning berikutnya

1. Review scope, pendekatan, peta kapabilitas, alur, serta usulan stack.
2. Tetapkan screen inventory dari alur dan daftar state tiap layar.
3. Tetapkan arah visual, token desain, komponen inti, dan microcopy.
4. Buat satu mockup mandiri per layar dengan state yang relevan; review layar sebelum masuk implementasi.
5. Selesaikan model data, kontrak API/sinkronisasi, diagram, kriteria EARS, dan target verifikasi pilot.
6. Susun spesifikasi dan rencana implementasi berdasarkan kapabilitas, kemudian readiness check dan pembekuan HANDOFF.md.

Untuk Flutter, mockup HTML merupakan alat review visual. Implementasi native mengikuti tokens, hierarchy, spacing, dan perilaku layar yang disetujui melalui padanan widget Flutter; aturan transplantasi literal HTML/Tailwind dalam SOP disesuaikan dengan platform mobile yang dipilih pengguna.

## Hal yang perlu diketahui sebelum handoff final

Perangkat pilot, jumlah kandang/operator, putaran pengumpulan telur, lokasi gudang pakan, cara koreksi, akses ke calon pengguna, jadwal, dan anggaran layanan. Penentuan target retensi, backup, serta kapasitas backend mengikuti ukuran pilot dan kebutuhan pengguna yang disepakati.

## Sumber teknis yang dicek

- [Flutter offline-first](https://docs.flutter.dev/app-architecture/design-patterns/offline-first): penyimpanan lokal, data remote, serta strategi read/write/sync perlu dipilih sesuai kebutuhan aplikasi.
- [Drift](https://drift.simonbinder.eu/): kandidat persistence berbasis SQLite untuk aplikasi Dart/Flutter.
- [Laravel Sanctum](https://laravel.com/framework/docs/13.x/sanctum): autentikasi token untuk aplikasi mobile; izin objek/role tetap ditetapkan pada backend TERNAVA.
- [Laravel queues](https://laravel.com/framework/docs/13.x/queues): kandidat mekanisme pekerjaan backend setelah transaksi.
- [FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started): kandidat pengiriman push; perilaku izin serta penerimaan bergantung perangkat/platform.

Sumber memberi dasar pilihan teknis, bukan bukti bahwa arsitektur TERNAVA telah diimplementasikan atau diuji.
