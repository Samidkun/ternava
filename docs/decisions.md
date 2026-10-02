# Catatan Keputusan TERNAVA

Tanggal: 1 Oktober 2026, Asia/Jakarta.

## Dipilih pengguna

| ID | Keputusan | Bukti percakapan |
|---|---|---|
| D-001 | Nama produk TERNAVA | “boleh tuh ternava” |
| D-002 | Menggunakan web-app-sop untuk planning | “lanjut planning pake web sop yak” |
| D-003 | Root project `/mnt/data/porto/ternava` | Pengguna meminta folder project di `/mnt/data/porto`; nama subfolder mengikuti produk |
| D-004 | Komoditas pertama ayam petelur | Jawaban klarifikasi: ayam petelur |
| D-005 | MVP mobile dengan backend untuk uji coba peternakan | Jawaban klarifikasi target tahap pertama |
| D-006 | Mobile menggunakan Flutter | Jawaban klarifikasi stack |
| D-007 | Scope dan stack rancangan awal disetujui untuk melanjutkan planning | Setelah review scope/stack: “sip,bagus,lanjutin planning nya” |
| D-008 | Belum ada calon peternakan; desain menggunakan skenario contoh dahulu | Jawaban klarifikasi pilot pada 1 Oktober 2026 |
| D-009 | Baseline visual yang disajikan diterima untuk melanjutkan planning | Respons terhadap paket review 24 layar: “sip,lanjutin planning nya”. Ini penerimaan untuk lanjut, bukan bukti pengamatan bahwa setiap file dibuka. |
| D-010 | Backend dirancang lokal dengan Docker dahulu | Jawaban hosting: “Belum ada; rancang lokal dengan Docker dulu”. Tidak ada provider, biaya, atau deployment yang dipesan. |

| D-011 | Spesifikasi P4 beserta AM-01/02 diterima; lanjut menyusun plan | “setuju sih,brrti kurang implement/eksekusi nya aja kan?” setelah paket review spesifikasi dan amendemen disajikan. Tidak menyatakan app sudah berjalan atau tiap file telah dibuka. |
| D-012 | Cukup sampai planning; eksekusi menunggu permintaan berikutnya | “wait"cukup ampe planning dulu aja gpp”. Tidak ada coding fitur, scaffold app, deployment, atau pengiriman pesan ke pihak lain pada tahap ini. |

## Klasifikasi SOP

- Jalur: architectural, produk baru.
- Tier: T2, karena target pilot melibatkan pengguna dan data operasional nyata.
- Ceremony: L, karena auth, akses pengguna, model data baru, dan sinkronisasi offline.
- Rigor: spec-anchored.
- Ukuran tim: belum dikonfirmasi; planning diasumsikan dikerjakan bersama pengguna di chat ini. Overlay tim diterapkan jika ada kolaborator repository.
- Prompt-roast, konteks planning saat ini: goal 2, context 2, scope 1, success 1, constraints 1, ambiguity 1 = 8/12. Gap: scope rinci, kondisi pilot, serta target terukur. Klarifikasi nama/komoditas/target/mobile sudah diberikan; kondisi lapangan dibahas sebelum spesifikasi final.

Update setelah D-007/D-008: arah scope/stack diterima dan penggunaan skenario contoh dikonfirmasi. Score untuk kelanjutan desain: goal 2, context 2, scope 2, success 1, constraints 2, ambiguity 1 = 10/12. Target pilot terukur dan kondisi lapangan tetap belum diverifikasi; ini tidak menyatakan readiness handoff. Detail sementara tercatat pada `planning-rulings.md` dan direview bersama preview.

## Baseline setelah review scope

D-007 menerima arah scope dan stack pada review sebelumnya. Baseline berikut digunakan untuk desain. Parameter contoh dan kebijakan detail pada `planning-rulings.md` tetap dibedakan dari fakta lapangan; penerimaan arah produk tidak membuktikan kebutuhan pilot.

| ID | Usulan | Alasan | Status |
|---|---|---|---|
| P-001 | Android sebagai perangkat pilot awal | Mengurangi variasi perangkat saat uji lapangan; dikoreksi jika operator menggunakan iOS | Baseline desain |
| P-002 | Satu peternakan pilot, beberapa kandang | Menguji alur yang utuh dengan cakupan terukur | Baseline desain |
| P-003 | Pencatatan agregat per kelompok ayam/kandang | Fokus komoditas ayam petelur; model individu tidak diperlukan untuk alur awal yang dibahas | Baseline desain |
| P-004 | Flutter + Drift/SQLite lokal | Memisahkan penyimpanan catatan dari ketersediaan jaringan | Stack diterima untuk planning |
| P-005 | Laravel REST API + PostgreSQL + Sanctum | Satu backend untuk izin, validasi, transaksi, sinkronisasi, dan laporan | Stack diterima untuk planning |
| P-006 | Input manual pada pilot | Perangkat sensor belum tersedia dalam konteks yang diberikan | Baseline desain |
| P-007 | FCM untuk push, inbox aplikasi sebagai riwayat | Penerimaan push tidak dijadikan satu-satunya bukti bahwa temuan tersedia | Stack diterima untuk planning |
| P-008 | Satu catatan harian per kelompok dan tanggal lokal peternakan | Mengurangi penghitungan ganda atas total produksi harian; koreksi memakai versi | Baseline desain, validasi sebelum pilot |
| P-009 | Zona waktu peternakan disimpan saat setup | Menetapkan batas tanggal laporan sesuai lokasi pilot | Baseline desain |

## Pertanyaan lapangan yang belum selesai

- Peternakan pilot yang bisa diakses, jumlah kandang/operator, serta Android/iOS yang tersedia.
- Produksi saat ini dicatat sebagai total harian atau per putaran pengumpulan telur.
- Gudang pakan terpusat atau pakan tersimpan terpisah per kandang.
- Apakah tim perlu bantuan migrasi catatan sebelumnya.
- Siapa yang menyetujui koreksi stok dan menindaklanjuti temuan.
- Jadwal, anggaran layanan, lokasi server, retensi data, dan ukuran pilot.

Pertanyaan ini tidak diisi sebagai fakta. R-01–R-21 memberi baseline desain contoh yang diterima bersama D-011; AC-47 tetap mewajibkan validasi kondisi nyata sebelum pilot. D-012 membatasi pekerjaan sekarang pada dokumen planning.

## Catatan folder

Pembuatan parent `/mnt/data/porto` awalnya gagal read-only ketika izin hanya mencakup path porto yang belum ada. Setelah akses tulis parent `/mnt/data` diberikan, folder project berhasil dibuat. Tidak dilakukan perubahan mount sistem.

Update 1 Oktober 2026: izin tulis ulang ke `/mnt/data/porto/ternava` tidak diberikan pada turn ini. Paket terbaru disimpan di output workspace; root project belum diperbarui. Salinan lama tetap tersedia dan tidak dihapus.

Update permintaan berikutnya, 1 Oktober 2026: pengguna meminta paket dipindahkan ke root pilihan. Izin tulis `/mnt/data/porto/ternava` diberikan; 6 file planning baru disalin dan 6 dokumen diperbarui setelah backup. Riwayat brainstorming tetap disimpan. Status lokasi README/planning-status/handoff diperbarui; coding/deployment tetap belum dimulai sesuai D-012.
