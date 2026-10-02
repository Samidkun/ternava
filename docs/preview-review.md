# Review Visual TERNAVA

1 Oktober 2026. Baseline P2.1 diterima untuk lanjut planning melalui D-009. Scope/stack sudah diterima; belum ada handoff implementasi yang dibekukan.

## Cara review

Buka `preview/index.html`. Pilih **Mulai sebagai operator** atau **Mulai sebagai pemilik**. Masing-masing layar dapat dibuka sendiri di `preview/mockup/<screen-id>.html`; font, CSS, JS, dan lisensi font disematkan tanpa build atau dependensi jaringan.

- Operator: `today` → `daily-form` → `sync-center` → `daily-history`; lalu `incident-list` → `incident-form` → `incident-detail`.
- Pemilik/admin: `home` → perhatian/kandang/pakan/temuan → `reports`.
- Setup: `farm-setup` → `cage-list`/`cage-form` → `flock-list`/`flock-form` → `team-list`/`member-form` → `task-form`.
- Pemulihan: pilih state offline/gagal/konflik/sesi habis yang tersedia; periksa penjelasan dan jalan berikutnya.

Toolbar “State layar” dan “Role contoh” adalah alat review, tidak masuk Flutter. Angka/nama rekaan bukan hasil riset peternakan. Navigasi/aksi contoh tidak memanggil API, mengirim pemberitahuan, atau membuat akun. Perubahan antarfile tidak menjadi data transaksi bersama; contoh CSV ditandai sebagai data contoh.

## Bukti verifikasi

Run terakhir harus menunjukkan 24 layar, 260 kombinasi layar/state/ukuran, tanpa failure atau script error. Interaksi yang dicek mencakup validasi harian, penyimpanan tertunda, kegagalan simpan, filter/search, konteks kandang, akses contoh, data laporan yang kosong, konflik, serta dialog keyboard. Laporan mesin dan screenshot berada di `preview/evidence/`.

Hasil run terakhir pada 1 Oktober 2026: **24 layar, 260 kombinasi, 0 failure, 0 script error**. Pemeriksaan source token/inventory juga lulus. Fokus dialog yang sempat gagal telah diperbaiki dan diverifikasi ulang.

Ini hasil preview HTML. Keamanan server, idempotensi, ketahanan offline, dan aksesibilitas native belum dapat dinyatakan lulus dari hasil tersebut.

## Persetujuan visual per layar

| Screen ID | Status | Bukti persetujuan |
|---|---|---|
| `login` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `farm-setup` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `cage-list` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `cage-form` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `flock-list` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `flock-form` | Baseline dan amendemen diterima | D-009 + D-011, AM-02, 1 Oktober 2026 |
| `team-list` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `member-form` | Baseline dan amendemen diterima | D-009 + D-011, AM-01, 1 Oktober 2026 |
| `home` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `today` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `task-form` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `task-detail` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `daily-form` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `daily-history` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `feed-stock` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `feed-entry` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `feed-type-form` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `incident-list` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `incident-form` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `incident-detail` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `reports` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `inbox` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `sync-center` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |
| `account` | Diterima untuk lanjut | D-009, 1 Oktober 2026 |

D-009 merujuk pada paket 24 layar yang disajikan bersama permintaan review. Respons pengguna dicatat sebagai penerimaan baseline tersebut untuk lanjut planning; tidak mengklaim pengguna membuka/memeriksa setiap state. Perubahan material dari baseline memerlukan review perubahan terkait sebelum implementasi.

## Tahap setelah review visual

Selesaikan model data/kontrak sync dan role, diagram, kriteria EARS dengan Verify, pilihan operasi pilot dan kebijakan data, spesifikasi, kemudian review spesifikasi. Rencana implementasi ditulis setelah spesifikasi diterima. Bootstrap/readiness serta HANDOFF.md baru diselesaikan ketika gate yang relevan terpenuhi. Data lapangan yang belum ada tetap ditandai sebagai ruling/validasi sebelum pilot.

## AM-01 — detail akun baru untuk review spesifikasi

Kolom “Sandi sementara”, kosong dan minimal 12 karakter, ditambahkan pada state membuat akun; edit mode tidak meminta sandi ini. Ini memperjelas serah akses R-09, tanpa layar/nav baru. Riset kontrak juga mempertahankan lokasi farm, keterangan kandang dan hasil checkbox yang sudah terlihat pada baseline. Pengguna menerima AM-01 bersama spesifikasi melalui D-011; tidak ada klaim bahwa semua state dibuka satu per satu.

Evidence260 kombinasi sebelumnya membuktikan baseline sebelum AM-01. Setelah perubahan, source syntax dan inventory diperiksa; pemeriksaan render/native baru belum dilakukan. Screenshot baseline tidak diklaim sebagai hasil render amendemen.

## AM-02 — alasan perubahan kelompok

State Edit data pada flock-form meminta alasan perubahan. Contoh edit kelompok yang sudah memiliki catatan mengunci populasi awal, tanggal dan kandang; status/code dapat berubah dengan alasan dan versi. Ini menerapkan histori R-07/R-21, bukan fitur baru. State edit juga membedakan akun baru dan edit pada member-form. Inventory sekarang 24 layar/132 state; evidence 260 kombinasi terdahulu tetap baseline sebelum amendemen. Dua amendemen diterima melalui D-011. Render ulang/native masih belum dibuktikan; penerimaan pengguna tidak menggantikan hasil uji.
