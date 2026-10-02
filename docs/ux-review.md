# Review UX TERNAVA

P2.4, 1 Oktober 2026. Walkthrough atas flow P2.0 dan mockup P2.1; belum uji pengguna. Skenario contoh disetujui pengguna karena belum ada calon pilot.

| Heuristic | Keputusan pada preview | Batas yang perlu diuji berikutnya |
|---|---|---|
| 1. Status terlihat | Draft/perangkat, menunggu, diterima, tertolak, dan waktu pembaruan dibedakan. | Durability, pengakuan server, foto, dan retry nyata belum diuji. |
| 2. Bahasa lapangan | Pakan kg, telur butir, populasi ekor, kandang, petugas, dan tindakan. Tanggal ISO diberi teks bulan Indonesia. | Pemahaman bahasa/istilah bersama operator pilot. |
| 3. Kontrol dan jalan keluar | Kembali sesuai area role; konfirmasi isian belum disimpan/keluar dengan antrean; Escape dan fokus dialog. | Android back, lifecycle, keyboard, dan device sharing pada Flutter. |
| 4. Konsistensi | Token tunggal, CTA yang sama untuk pekerjaan yang sama, tab mengikuti role. | Transplantasi native dari layout/behavior yang disetujui. |
| 5. Pencegahan error | Label/satuan permanen, angka valid, draft boleh belum lengkap, kiriman tertunda read-only, revisi role pengelola. | Batas populasi, tanggal, persediaan dan otorisasi wajib dipaksakan backend. |
| 6. Recognition | Kandang/kelompok terpilih terlihat; penugasan/status muncul di baris, bukan kode yang harus diingat. | Apakah nama kelompok memang digunakan operator lapangan. |
| 7. Efisiensi | Total harian satu form, pakan tidak diinput dua kali, kondisi/populasi opsional dibuka saat perlu, filter tanggal/kandang. | Waktu dan kesalahan pencatatan nyata; jangan menganggap form sudah cepat. |
| 8. Fokus | Operator memilih pekerjaan/catatan; pemilik memilih perhatian. Tidak ada deretan widget tak terkait. | 24 layar mencakup setup/admin; operator tidak diwajibkan melalui semuanya. |
| 9. Pemulihan error | Isian dipertahankan; pesan menyebut sebab/tindakan; konflik ditinjau, bukan ditimpa; laporan kosong bukan nol. | Respons API domain harus dipetakan ke pesan yang sama saat implementasi. |
| 10. Bantuan | Hint di field, empty state dengan langkah berikutnya, penjelasan akses/masuk pertama. | Bantuan operasional dan onboarding lapangan perlu dicoba dengan calon pilot. |

## Perubahan dari inspeksi render

- Dialog diberi trap keyboard eksplisit setelah pemeriksaan menemukan fokus bisa keluar.
- Root tab tidak memakai tombol kembali yang menuju halaman yang sama.
- Angka catatan baru tetap kosong; kondisi awal “Belum diperiksa”.
- Kondisi/populasi/foto memakai progressive disclosure agar form utama lebih pendek.
- Field satuan memakai satu batas input; tanggal diberi teks bulan untuk menghindari ambiguitas format browser.
- Filter pencarian tidak diperlakukan sebagai isian form yang belum disimpan.
- Tombol foto/form dinonaktifkan pada catatan menunggu atau read-only.
- Konteks kandang/tanggal mengikuti navigasi contoh, dan CSV mengikuti filter contoh.

## Bukti dan batas pemeriksaan

`preview/evidence/checks.json`: pemeriksaan Chromium atas 24 layar dan 130 state pada dua ukuran (320/414px), pemetaan kontrol ke AC, label, target minimum 48px, clipping, script error, dan skenario interaksi. Screenshot dipakai untuk inspeksi hierarki/form. Hasil akhir dicatat di `preview-review.md` setelah run selesai.

`preview/evidence/design-checks.json`: struktur YAML, token references, pasangan warna komponen, dan kesesuaian inventory/manifest. Pasangan teks komponen di atas 4,5:1; batas input di atas 3:1. Ini pemeriksaan lokal; CLI `@google/design.md` tidak tersedia dan tidak diinstal.

Pemeriksaan menggunakan browser yang tersedia dan dipandu ui-render-gates; bukan seluruh runner resmi skill atau sertifikasi WCAG. Axe tidak tersedia lokal dan tidak dijalankan. TalkBack, text scaling Android 200%, perangkat nyata, backend, sync setelah crash, deduplikasi, izin server, dan restore belum diuji. Semuanya masuk verifikasi implementasi; preview tidak membuktikannya.
