# Panduan pengguna TERNAVA (operator & pengelola)

Panduan ini memakai label yang benar-benar tampil pada aplikasi. TERNAVA
membedakan **"Tersimpan di perangkat"** (baru masuk antrean lokal) dari
**"Diterima sistem"** (server sudah mengirim ACK). Jangan menghapus data
aplikasi selama masih ada item di **Pusat Sinkronisasi**.

## Operator

### 1. Masuk

1. Buka aplikasi → layar **"Masuk ke TERNAVA"**.
2. Isi **Nama Pengguna** dan **Kata Sandi**, lalu tekan **Masuk**.
3. Login pertama dan sinkron referensi pertama **butuh internet**. Jika belum
   tersambung, aplikasi menampilkan *"Sambungkan internet untuk masuk pertama
   kali."* — sambungkan lalu ulangi.

### 2. Catat kondisi kandang (Hari ini → Catatan Harian)

1. Tab **Hari ini** menampilkan **"Daftar Kandang Anda"**. Setiap kandang
   berlabel **Sudah dicatat** atau **Belum dicatat**.
2. Ketuk kandang → layar **"Catatan <Nama Kandang>"**.
3. Isi **Jumlah Pakan (kg)** (wajib, dua angka desimal, mis. `12.50`),
   **Jumlah Telur (butir)**, **Ayam Mati (ekor, opsional)**, pilih
   **Kondisi Kandang** (Normal / Perlu Perhatian / Kritis), dan **Catatan
   Tambahan (opsional)**.
4. Tekan **Simpan catatan**. Muncul *"Catatan tersimpan lokal, menunggu
   sinkronisasi."* — artinya baru **tersimpan di perangkat**, belum diterima
   server.
5. Ingin menyimpan tanpa mengirim? Tekan **Simpan Draf** (*"Draf lokal
   disimpan."*). Draf tidak masuk antrean kirim.

**Offline:** catatan tetap boleh diisi. Item akan **menunggu** sampai jaringan
kembali; setelah tersambung, **Pusat Sinkronisasi** mengirimnya sekali.

### 3. Pekerjaan / tugas (Detail Tugas)

1. Tab **Hari ini** → **Tugas Hari Ini** → ketuk tugas → **Detail Tugas**.
2. Isi hasil/checklist dan catatan, lalu simpan. Hasil disimpan lokal dulu;
   status **diproses/selesai** baru berubah **setelah ACK server**.
3. Tugas yang dibatalkan/berubah menjadi **perlu ditinjau** — buka detail untuk
   penjelasan, jangan menimpa otomatis.

### 4. Temuan

1. Tab **Temuan** → **Laporkan temuan**.
2. Tulis **pengamatan** (teks ini **tidak pernah hilang** meski foto gagal),
   pilih kandang, lalu **Simpan temuan**.
3. Foto bersifat opsional dan statusnya **terpisah** dari teks: foto bisa
   *tertunda* tanpa menghapus pengamatan. Format JPEG/PNG, maksimal 2 MiB,
   maksimal 3 foto per catatan.

### 5. Akun

1. Tab **Akun** → **"Akun & Pengaturan"** (nama, peran, peternakan, zona waktu).
2. **Keluar Akun** → konfirmasi *"Keluar dari aplikasi?"*. Partisi lokal
   dikunci setelah keluar; **antrean tidak dibuang** dan terkirim lagi setelah
   Anda masuk kembali.

## Pengelola (owner/admin)

- **Ringkasan Hari Ini** — kandang belum tercatat, temuan, stok. Data yang belum
  ada ditampilkan **"Belum dicatat"**, bukan angka nol.
- **Kandang** → **Tambah Kandang**; buka kandang untuk **Kelompok Ayam**
  (**Kelompok Baru**).
- **Pakan** — **Saldo Pakan** dan **Transaksi Pakan** (**Simpan transaksi**);
  jenis pakan lewat **Jenis pakan** (**Simpan jenis pakan**). Pemakaian harian
  berasal dari Catatan Harian, **tidak diinput ulang** di sini.
- **Tim Peternakan** → **Tambah Anggota** (peran & penugasan kandang).
- **Jadwal Tugas** (**Simpan tugas**), **Laporan** (**Ekspor CSV**).
- Temuan: **Tugaskan petugas**, **Tandai diproses**, **Tutup temuan** (tutup
  wajib dengan keterangan).

## Pemulihan (Sync recovery)

Buka **Pusat Sinkronisasi** (status pengiriman) untuk melihat item yang **belum
diterima sistem**.

| Gejala | Arti | Tindakan |
|---|---|---|
| Menunggu | Belum terkirim (offline) | Sambungkan internet, tekan **Coba lagi** |
| Perlu ditinjau | Konflik/validasi (409/422) | Baca pesan, perbaiki isian, kirim ulang |
| Autentikasi berhenti | Sesi 401/403 | **Masuk** ulang; antrean **tetap tersimpan** |
| Batas laju (429) | Terlalu banyak permintaan | Tunggu sesuai waktu yang diminta, ulangi |

Item **tidak pernah dihapus otomatis**. Jangan keluar/menghapus aplikasi saat
antrean masih berisi — data lokal bisa hilang.

## Batas yang perlu diketahui

- Panduan ini menyertakan hasil uji perangkat otomatis; **pemeriksaan TalkBack
  manual dan mati proses OS nyata** dicatat di
  `../evidence/android-uat.md` dan belum diklaim lulus tanpa perangkat nyata.
