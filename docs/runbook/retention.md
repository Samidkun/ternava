# Runbook — Retensi, penghapusan dan penutupan farm

Task: T41 · Acceptance: AC-36, AC-41, AC-46. Sumber kebijakan: `../operations-security.md` (bagian "Data, retensi dan recovery"). Angka di dokumen ini harus sama dengan `backend/config/ternava.php`.

## 1. Jendela retensi

| Data | Jendela | Command/efek |
|---|---|---|
| Catatan operasional, ledger (`daily_records`, `feed_entries`, `population_entries`, `daily_revisions`) | **730 hari** | `php artisan ternava:retention` |
| Audit trail (`audit_events`) | **730 hari** | `php artisan ternava:retention` |
| Foto (byte private + baris `attachments`) | **180 hari** | `php artisan ternava:retention` |
| Inbox (`inbox_items`) | **90 hari** | `php artisan ternava:retention` |
| Sync changes (`sync_changes`) | **30 hari** | `php artisan ternava:retention` |
| Log teredaksi | **14 hari** | di luar app (rotasi log host) |
| Backup | **30 hari** | `ops/backup.sh` (T43) |

Semua nilai di atas dapat diubah lewat config `ternava.retention.*` bila pilot mengubah kebijakan; ubah juga `operations-security.md` agar tidak drift.

## 2. Menjalankan retensi

```bash
# di dalam container api atau host dengan DB terjangkau
php artisan ternava:retention
```

Sifat yang dijamin (AC-46):

- **Dedup dipertahankan selama farm aktif.** Tabel `idempotency_receipts` **tidak pernah** dibersihkan oleh job ini. Ini penting agar antrean lama yang di-replay tidak membuat efek bisnis ganda (`App\Support\MutationExecutor` memeriksa receipt sebelum menulis).
- **Ledger utuh, bukan dihapus sebagian.** Catatan bisnis dihapus sebagai satu kelompok umur pada jendela 730 hari; tidak ada penghapusan parsial yang memutus referensi ledger.
- **Setiap penghapusan dicatat.** Job menulis baris append-only `audit_events.action = 'retention.deletion'` (per tabel + jumlah baris) sehingga restore dapat **menerapkan ulang catatan penghapusan setelah timestamp backup**.
- **Idempoten.** Menjalankan job dua kali tidak menggandakan jurnal dan tidak menghapus data yang masih dalam jendela.

Verifikasi cepat:

```bash
php artisan ternava:retention     # exit 0
php artisan ternava:retention     # exit 0, jurnal tidak bertambah untuk data yang sama
```

## 3. Penutupan farm (farm closure)

```bash
php artisan ternava:close-farm {farm-uuid}
```

Efek: menulis snapshot JSON (farm + jumlah record) ke `storage/app/private/exports/farm-<id>-<ts>.json`, menonaktifkan seluruh `memberships` farm (pencabutan akses) **tanpa menghapus user** (ledger tetap menunjuk actor ID), dan menulis `audit_events.action = 'farm.closure'`. Baris `farms` dan ledger tidak di-hard-delete.

Alur manual sesuai kebijakan: export → konfirmasi owner → scope tertulis → jalankan command. Pengelola akun boleh dinonaktifkan/pseudonymized tanpa mengubah ledger actor ID.

## 4. Restore setelah backup

1. Restore DB + private uploads dari backup (T43).
2. Terapkan ulang catatan penghapusan: hapus baris yang punya `audit_events.action = 'retention.deletion'` dengan `accepted_at` **lebih baru dari** timestamp backup.
3. **Jangan** membuat ulang `idempotency_receipts` dengan key baru; biarkan receipt lama apa adanya agar replay tetap dedup.

## 5. Hubungan dengan restore/rollback

Lihat `restore.md` (T43) untuk drill restore penuh. Catatan penting: setelah restore, dedup key dari periode sebelum backup tetap valid; jangan mengulang efek bisnis dengan key baru.

## 6. Rate limit (AC-41) — ringkas

Login 5/menit per username+IP dan 30/menit per IP (di `SessionController`); API authenticated 120/menit per user; upload 10/menit; ekspor 3/menit (limiter bernama `uploads`/`exports` di `AppServiceProvider`, dipasang via middleware `throttle:*`). JSON maksimal 64 KiB dan limit query/range (laporan ≤183 hari) ditegakkan di middleware `RequestLimits` dan `ReportService`. Semua respons 429 wajib menyertakan `Retry-After`.
