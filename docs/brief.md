# TERNAVA — Pencatatan & Monitoring Peternakan Ayam Petelur

**Catat aktivitas kandang, pantau penggunaan pakan, dan tindak lanjuti masalah dalam satu aplikasi.**

Versi 2 — konsep produk, 1 Oktober 2026. Disusun dari brief awal dan riset web eksploratif. Nama TERNAVA, fokus ayam petelur, target MVP mobile dengan backend, Flutter, serta arah scope/stack sudah diterima pengguna untuk planning. Baseline visual diterima untuk lanjut melalui D-009; spesifikasi detail P4 dan amendemen sandi sementara masih untuk review; dokumen ini belum menjadi spesifikasi atau handoff implementasi yang dibekukan.

**Nama produk yang dipilih pengguna:** TERNAVA, dibaca ter-na-va. Nama rekaan ini terinspirasi bunyi kata ternak; bukan akronim. Pemeriksaan web awal belum menemukan aplikasi peternakan bernama persis TERNAVA. Ketersediaan domain dan merek belum diverifikasi.

## Deskripsi Project

TERNAVA adalah aplikasi mobile untuk operasional harian peternakan ayam petelur. Aplikasi ini membantu pemilik dan tim kandang mencatat penggunaan pakan, produksi telur, pekerjaan harian, serta temuan kondisi ayam dan tindak lanjutnya.

Operator menggunakan TERNAVA untuk melihat pekerjaan, mencatat aktivitas dan kondisi ternak, serta melaporkan masalah. Admin mengatur data, jadwal, dan penugasan. Pemilik memperoleh ringkasan kondisi peternakan berdasarkan catatan yang masuk, termasuk pekerjaan yang belum selesai dan masalah yang masih membutuhkan tindakan.

TERNAVA dirancang agar pencatatan tetap dapat dilakukan ketika koneksi internet terbatas. Informasi menampilkan waktu pencatatan, waktu pembaruan, serta status sinkronisasi agar pengguna memahami kesegaran data yang dipantau.

## Latar Belakang Masalah

Penerapan pencatatan digital perlu menyesuaikan kebiasaan dan kemampuan pengguna. Penelitian SIMAPI pada peternak sapi di Boyolali menemukan variasi penerimaan aplikasi, termasuk pengguna yang lebih nyaman dengan pencatatan manual serta hambatan kemampuan menggunakan teknologi. Hasilnya menekankan pendekatan partisipatif dan pendampingan. [Penelitian UGM, 2025](https://etd.repository.ugm.ac.id/penelitian/detail/263795).

Penggunaan pakan perlu dipantau karena berkaitan dengan biaya usaha. Dalam pemberitaan kegiatan untuk peternak ayam petelur di Probolinggo, Kementerian Pertanian menyebut biaya pakan dapat melebihi 70% biaya produksi. Angka ini berlaku pada konteks ayam petelur yang dibahas, sehingga tidak digunakan sebagai angka universal semua peternakan. [Kementan, 7 Agustus 2026](https://bpmsph.ditjenpkh.pertanian.go.id/berita/kementan-bekali-peternak-probolinggo-formulasi-pakan-sendiri-biaya-produksi-turun-untung-naik).

Ketersediaan koneksi juga menjadi pertimbangan. Laporan Kinerja Direktorat Kesehatan Hewan 2024 menjelaskan bahwa iSIKHNAS mempertahankan pelaporan melalui SMS untuk mengatasi keterbatasan perangkat dan sinyal internet. Hal ini menjadi dasar untuk menguji kebutuhan pencatatan offline pada pengguna TERNAVA. [Laporan Kinerja Direktorat Kesehatan Hewan 2024, halaman bernomor 91](https://ditjenpkh.pertanian.go.id/storage/master/file/jU8O8GTm_LAKIN_DitKeswan_2024.pdf#page=92).

Pemantauan kesehatan membutuhkan alur pelaporan dan respons yang jelas. iSIKHNAS menghubungkan pengumpulan data lapangan dengan laporan serta peringatan bagi petugas yang perlu merespons. Sementara itu, FAO melaporkan bahwa program biosekuriti bersama Kementan di tiga wilayah pilot memperkuat praktik pencegahan serta deteksi dan pelaporan kasus. [iSIKHNAS](https://isikhnas.pertanian.go.id/), [FAO, 18 Desember 2025](https://www.fao.org/indonesia/news/detail/ministry-of-agriculture--fao-call-for-national-replication-of-biosecurity-programme-against-african-swine-fever/en).

Implikasi desain untuk TERNAVA adalah mempermudah pencatatan, menjaga keterlacakan data, dan menghubungkan temuan dengan penanggung jawab serta tindak lanjut. Ini merupakan kesimpulan desain dari riset awal, bukan bukti bahwa TERNAVA sudah diterima pasar atau meningkatkan keuntungan usaha.

## Target Pengguna

Segmen awal yang dipilih adalah peternakan ayam petelur. Scope pilot yang diusulkan mencakup satu peternakan dengan beberapa kandang dan pembagian pekerjaan antara pemilik serta petugas kandang. Formulir, satuan, dan laporan mengikuti pekerjaan pada segmen ini. Target tahap pertama adalah MVP mobile Flutter dengan backend untuk uji coba peternakan.

| Role | Kebutuhan utama |
|---|---|
| Pemilik | Mengetahui kondisi operasional, penggunaan pakan, produksi, dan masalah yang membutuhkan keputusan |
| Admin | Mengelola data kandang/ternak, persediaan, jadwal, penugasan, dan akses pengguna |
| Operator | Melihat tugas, mencatat aktivitas lapangan dengan cepat, dan melaporkan temuan |

Pada peternakan dengan tim kecil, pemilik dapat menjalankan pekerjaan administrasi. Penggunaan aplikasi tidak mensyaratkan adanya pegawai admin tersendiri.

## Tujuan Project

- Membantu tim mencatat pekerjaan dan kondisi kandang secara konsisten.
- Menyediakan riwayat penggunaan pakan dan perubahan stok yang dapat ditelusuri.
- Menghubungkan temuan di lapangan dengan penanggung jawab serta tindak lanjut.
- Membantu pemilik membaca perubahan produksi dan kondisi operasional dari data yang tersedia.
- Mempermudah penyusunan laporan dengan menggunakan catatan yang sudah masuk.

## Fitur Utama MVP

### 1. Setup Peternakan dan Akses Pengguna

Pengaturan awal peternakan, kandang, pengguna, serta penanggung jawab. Setup pertama dan petunjuk kontekstual mengarahkan pengguna hingga membuat catatan pertama; tidak ada carousel onboarding terpisah. Hak akses mengikuti peran dan kandang yang menjadi tanggung jawab pengguna.

### 2. Pekerjaan Hari Ini

Daftar tugas dan jadwal operasional per kandang. Pengguna dapat melihat pekerjaan yang belum dilakukan, menyelesaikan tugas, serta mencatat kendala pelaksanaan. Contoh tugas mengikuti SOP peternakan pilot.

### 3. Pencatatan Harian

Formulir singkat per kandang/kelompok ayam untuk mencatat pemakaian pakan dalam kg, produksi telur dalam butir, kematian atau perubahan populasi, serta kondisi yang diamati. Populasi awal dicatat pada setup kelompok ayam; formulir harian mencatat perubahan yang terjadi. Catatan dapat dilengkapi foto dan keterangan.

### 4. Stok dan Penggunaan Pakan

Pencatatan penerimaan pakan, pemakaian per kandang atau kelompok ternak, serta koreksi stok dengan alasan. Ringkasan menunjukkan sisa stok, riwayat pemakaian, dan peringatan ketika stok melewati batas minimum yang ditetapkan pengelola. Harga dan total penerimaan dicatat pada ledger; ringkasan biaya/perhitungan laba bukan fitur laporan MVP.

### 5. Temuan Kesehatan dan Tindak Lanjut

Pelaporan temuan kondisi ternak, foto pendukung, penanggung jawab, status penanganan, serta riwayat tindakan. Jadwal vaksinasi atau pemeriksaan mengikuti jadwal yang dimasukkan pengelola. Tindakan medis dicatat berdasarkan arahan petugas kesehatan hewan.

### 6. Dashboard Perhatian

Ringkasan pekerjaan yang belum selesai, temuan terbuka, stok yang melewati batas minimum, dan perubahan produksi yang perlu diperiksa. Setiap informasi mengarah ke catatan atau tindakan terkait. Data yang belum dicatat ditampilkan sebagai belum tersedia atau belum diperiksa.

### 7. Laporan Operasional

Ringkasan harian, mingguan, dan bulanan berdasarkan catatan yang tersimpan. Pengguna dapat memfilter kandang dan periode, melihat kelengkapan pencatatan, serta membagikan laporan. Data yang belum lengkap ditandai agar tidak terbaca sebagai nilai nol atau kondisi normal.

### 8. Pencatatan Offline dan Notifikasi

Catatan lapangan dapat disimpan pada perangkat ketika internet tidak tersedia, kemudian disinkronkan saat koneksi kembali. Pengguna memperoleh status penyimpanan dan sinkronisasi yang jelas. Notifikasi tugas atau temuan dikirim kepada pengguna terkait setelah data tersinkron; pembaruan dashboard mengikuti data yang diterima sistem.

## Alur Utama

Operator membuka pekerjaan hari ini → memilih kandang → mencatat aktivitas dan kondisi → mengirim temuan jika ada → admin/pemilik menetapkan tindak lanjut → petugas mencatat penyelesaian → ringkasan dan laporan diperbarui dari data yang diterima.

## Prinsip UI/UX

- Pencatatan memakai bahasa yang dipahami tim peternakan dan formulir yang sesuai dengan tugasnya.
- Aksi utama mudah dijangkau pada layar mobile, dengan label yang jelas dan konfirmasi hasil penyimpanan.
- Waktu pencatatan, pembaruan, dan sinkronisasi terlihat pada informasi yang memerlukannya.
- Status belum diperiksa, ditemukan masalah, sedang ditangani, dan selesai dibedakan dengan teks yang jelas.
- Koreksi catatan memiliki riwayat agar perubahan dapat ditelusuri.

## Arah Teknologi

- Mobile: Flutter, dipilih pengguna pada 1 Oktober 2026. Arsitektur offline disusun berdasarkan kebutuhan pencatatan lapangan.
- Data: penyimpanan lokal untuk catatan lapangan dan backend dengan REST API untuk sinkronisasi serta laporan.
- Akses: otorisasi berdasarkan peternakan, role, dan penugasan kandang.
- Notifikasi: pengingat pada perangkat serta push notification untuk pembaruan yang sudah diterima server.
- Dashboard pemilik tersedia dalam aplikasi mobile. Kebutuhan dashboard web dievaluasi melalui proses kerja pengguna.

Versi dan layanan tertentu dipilih setelah kebutuhan pilot serta batasan tim dipastikan.

## Pengembangan Lanjutan

Integrasi sensor kandang, pencatatan individu dan reproduksi yang lebih mendalam, dukungan beberapa peternakan, serta analisis biaya usaha yang lebih lengkap dapat dikembangkan berdasarkan kebutuhan yang terbukti pada pilot.

Ringkasan biaya pada MVP mencakup komponen yang benar-benar dicatat. Perhitungan laba usaha membutuhkan pencatatan pendapatan dan seluruh biaya yang relevan.

## Ukuran Keberhasilan Pilot

Pilot mengevaluasi waktu yang dibutuhkan operator untuk mencatat, kelengkapan catatan harian, kesesuaian stok aplikasi dengan pemeriksaan fisik, waktu antara pelaporan temuan dan tindak lanjut, serta penggunaan ringkasan oleh pemilik untuk mengambil tindakan.

Uji coba juga memastikan catatan offline dapat tersinkron tanpa hilang atau terduplikasi. Target angka ditetapkan dari pengukuran proses awal peternakan pilot.

## Keputusan yang Perlu Dibahas Sebelum Desain Final

1. Peternakan ayam petelur yang paling mudah dilibatkan sebagai pilot, jumlah kandang, dan perangkat operator.
2. Siapa pencatat harian dan bagaimana proses pencatatan saat ini.
3. Perangkat serta kondisi koneksi di lokasi kandang.
4. Data yang sudah tersedia dan cara pengecekan kebenarannya.
5. Jadwal dan ukuran pilot untuk MVP mobile Flutter dengan backend, sesuai target yang dipilih pengguna.

## Catatan Metode dan Batas Riset

Riset dilakukan pada 1 Oktober 2026 dengan pencarian masalah pencatatan, adopsi digital, biaya pakan, konektivitas, dan pelaporan kesehatan pada konteks Indonesia. Sumber utama yang digunakan adalah repositori penelitian UGM, publikasi Kementan, laporan kinerja pemerintah, sistem resmi iSIKHNAS, dan laporan program FAO. Abstrak penelitian serta bagian sumber yang relevan dibaca; ini bukan systematic review.

Studi lapangan memiliki konteks daerah dan komoditas tertentu. Temuan peternak sapi, ayam petelur, dan program peternakan babi tidak dianggap mewakili semua peternakan. Riset ini memberi dasar untuk hipotesis desain. Kebutuhan spesifik, kemauan membayar, persaingan produk, serta manfaat terukur TERNAVA perlu divalidasi bersama calon pengguna.
