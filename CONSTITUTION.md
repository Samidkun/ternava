# Prinsip Project TERNAVA

Status: baseline prinsip sesuai scope yang diterima; detail normatif direview bersama spesifikasi P4, 1 Oktober 2026.

1. **Catatan lapangan mendahului dashboard.** Ringkasan berasal dari data yang benar-benar tercatat dan menampilkan kelengkapannya.
2. **Belum diperiksa berbeda dari kondisi normal.** Nilai kosong tidak diubah menjadi nol atau status aman.
3. **Simpan sebelum menyatakan berhasil.** Konfirmasi pada perangkat diberikan setelah penyimpanan lokal berhasil; status terkirim diberikan setelah server mengakui data.
4. **Pengiriman ulang tidak menggandakan transaksi.** Satu aksi memiliki identitas tetap untuk seluruh percobaan pengiriman.
5. **Koreksi dapat ditelusuri.** Perubahan angka, stok, dan status menyimpan pelaku, waktu, alasan, serta nilai sebelumnya.
6. **Akses dibatasi oleh peternakan, peran, dan penugasan.** Server memeriksa izin pada setiap operasi; penyembunyian tombol bukan otorisasi.
7. **Pakan, populasi, dan produksi mengikuti satuan serta periode yang jelas.** Nilai tidak valid ditolak sebelum memengaruhi laporan atau stok.
8. **Temuan mempunyai pemilik dan tindakan.** Peringatan mengarah ke catatan yang bisa ditindaklanjuti.
9. **Keamanan dan pemulihan data menjadi bagian pilot.** Token dan kata sandi tidak dicatat di log; backup diuji lewat pemulihan sebelum data pilot dipakai sebagai referensi utama.
10. **Spesifikasi dan implementasi bergerak bersama.** Kriteria diterjemahkan menjadi pengujian perilaku. Perubahan keputusan yang dibekukan dicatat sebagai amendment.
11. **Desain mengikuti pekerjaan lapangan.** Bahasa Indonesia yang jelas, satu tindakan utama per layar, aksesibilitas, serta kondisi kosong/gagal/offline dirancang sejak awal.
12. **Pilot mengevaluasi manfaat.** Waktu pencatatan, kelengkapan data, akurasi stok, dan tindak lanjut diukur dari kondisi awal pengguna, bukan diklaim dari tampilan aplikasi.
