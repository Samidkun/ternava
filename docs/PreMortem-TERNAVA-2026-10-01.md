# Pre-Mortem TERNAVA — 1 Oktober 2026

Status: satu pass pada rancangan awal, bukan hasil pengujian aplikasi. Tidak ada tanggal launch yang ditetapkan; “gagal saat pilot” digunakan sebagai skenario analisis.

## Tigers — risiko nyata dalam rancangan

| Risiko | Urgensi | Alasan | Mitigasi yang diusulkan | Owner fungsi | Batas keputusan |
|---|---|---|---|---|---|
| Pengiriman ulang menggandakan pakan atau telur | Menghalangi pilot | Jaringan putus dapat membuat perangkat tidak mengetahui hasil pengiriman | Identitas aksi tetap, hasil idempotensi backend, transaksi, dan uji ulang setelah respons hilang | Backend + mobile | Kontrak sync sebelum handoff |
| Dua operator mengubah total hari yang sama | Menghalangi pilot | Masing-masing dapat memegang versi berbeda | Tetapkan total harian vs event pengumpulan; versi dan resolusi konflik yang terlihat | Produk + backend | Model data sebelum handoff |
| Stok aplikasi berbeda dari stok fisik | Menghalangi pilot | Saldo awal dan pemakaian bisa belum tercatat | Verifikasi saldo awal, ledger, audit koreksi, dan pemeriksaan fisik terjadwal | Admin peternakan + produk | Sebelum input data pilot |
| Cache/antrean offline hilang atau tercampur saat pindah akun | Menghalangi pilot | Perangkat dapat dipakai bergantian | Penyimpanan terisolasi per akun/peternakan, flow keluar dengan catatan belum terkirim, uji relaunch dan pergantian akun | Mobile | Sebelum uji lapangan |
| Operator mengakses kandang/peternakan di luar tugas | Menghalangi pilot | ID objek dapat dikirim langsung ke API | Otorisasi objek pada setiap operasi dan uji lintas akses | Backend | Sebelum pilot |
| Form terlalu panjang sehingga pencatatan terlewat | Menghalangi pilot | Catatan merupakan dasar dashboard | Uji satu alur nyata dengan operator; kolom hanya yang membantu pekerjaan dan keputusan | UX + pengguna pilot | Review mockup/form |
| Backup tidak bisa dipulihkan | Menghalangi penggunaan data pilot sebagai referensi utama | Backup yang ada belum tentu menghasilkan pemulihan yang benar | Rehearsal restore dan rekonsiliasi data; dokumentasikan prosedurnya | Operasional backend | Sebelum data pilot menjadi referensi utama |
| Push terlambat sementara masalah belum ditangani | Dipantau pada pilot | Penerimaan push bergantung perangkat dan jaringan | Inbox, penanggung jawab, status, dan jalur komunikasi lapangan sesuai SOP peternakan | Produk + admin | Flow sebelum handoff |

## Paper tigers — perhatian yang tidak memerlukan perluasan MVP sekarang

- Dukungan seluruh komoditas sejak awal. Pengguna sudah memilih ayam petelur; model komoditas lain dievaluasi setelah pilot.
- Microservices dan kapasitas nasional sejak awal. Ukuran pilot ditetapkan dahulu; backend modular tunggal dapat dinilai terhadap target pilot yang konkret.
- Sensor sebagai prasyarat seluruh monitoring. Pencatatan manual dapat menjadi asal informasi operasional; kebutuhan sensor diuji sebagai pengembangan terpisah.

## Elephants — asumsi yang belum terbukti

- Akses ke peternakan yang bersedia melakukan uji coba belum diketahui.
- Pemilik mungkin memerlukan laporan biaya yang lebih luas daripada komponen pakan yang tercatat.
- Sistem pencatatan telur bisa mengikuti beberapa pengumpulan atau beberapa shift per hari.
- Gudang dan penimbangan pakan dapat berbeda antar peternakan.
- Android-first belum dikonfirmasi terhadap perangkat operator.
- Jadwal, anggaran, retensi data, dan penanggung jawab operasional backend belum ditentukan.

Investigasi yang disarankan: observasi satu hari kerja, foto/contoh formulir yang saat ini digunakan jika pengguna dapat menyediakan, uji flow pada operator, dan penetapan ukuran pilot bersama pemilik. Persetujuan scope tidak otomatis membuktikan asumsi lapangan ini.
