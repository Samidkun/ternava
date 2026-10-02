# Runbook — Backup, restore dan metrik gangguan

Task: T43 · Acceptance: AC-43, AC-45, AC-46. Sumber kebijakan: `../operations-security.md`
(bagian "Data, retensi dan recovery" dan "Operasional, observability dan degradasi").
Angka di dokumen ini harus sama dengan `ops/lib.sh`, `ops/health-monitor.py` dan
`backend/config/ternava.php`.

## 1. Ringkasan

| Target | Nilai | Di mana |
|---|---|---|
| Retensi backup | **30 hari** | `ops/backup.sh` (prune otomatis) |
| RPO (kehilangan maksimal) | **<= 24 jam** | backup harian; dicek `restore.sh` |
| RTO (waktu pulih) | **<= 4 jam** | diukur `restore.sh` tiap drill |
| Backup terenkripsi | AES-256-CBC/PBKDF2 | kunci dari env/file, **di luar Git** |
| SLO API | **99,5% bulanan** | diukur setelah pilot berjalan (server + probe eksternal) |

Backup berisi: `database.dump` (pg_dump custom), `uploads.tar.gz` (hanya
`attachments`; folder `exports` turunan, tidak dibackup), `manifest.json`
(jumlah baris per tabel, total ledger, watermark jurnal penghapusan, sha256) dan
`checksums.txt`. Payload dibungkus `openssl` menjadi `<bundle>.tar.gz.enc`.

## 2. Menjalankan backup

Kunci enkripsi **tidak pernah** masuk Git. Set salah satu:

```bash
export TERNAVA_BACKUP_KEY="<32-byte hex>"        # dari secret manager
# atau
export TERNAVA_BACKUP_KEY_FILE=/etc/ternava/backup.key   # file 600, di luar repo
```

Dry-run (tidak menulis apa pun — dipakai sebagai smoke test di CI):

```bash
bash ops/backup.sh --dry-run
```

Backup nyata (harian, off-host — arahkan `--dir` ke volume/host terpisah):

```bash
bash ops/backup.sh --dir /srv/ternava-backups
```

Data fiktif lokal boleh memakai `--allow-unencrypted`; **jangan** dipakai untuk
data nyata. Kredensial DB dibaca dari `backend/.env` (atau `DATABASE_URL`) dan
hanya diteruskan ke `pg_dump` lewat environment — tidak pernah muncul di `ps`.

### Jadwal (contoh cron host)

```cron
# harian 02:15 WIB, off-host, retensi 30 hari ditangani script
15 2 * * *  TERNAVA_BACKUP_KEY_FILE=/etc/ternava/backup.key /opt/ternava/ops/backup.sh --dir /srv/ternava-backups >> /var/log/ternava-backup.log 2>&1
```

## 3. Restore drill (environment terpisah)

`ops/restore.sh` **fail-closed**: tanpa manifest backup **dan** database
terisolasi ia menolak berjalan (exit 2) — restore tanpa tujuan yang aman adalah
insiden. Ia tidak pernah menyentuh database produksi.

```bash
# 1. siapkan database terisolasi (nama berbeda!)
createdb -h 127.0.0.1 -U ternava ternava_restore

# 2. jalankan drill
bash ops/restore.sh --verify-isolated \
  --manifest /srv/ternava-backups/ternava-<ts>/manifest.json \
  --isolated-db-url "postgresql://ternava:***@127.0.0.1:5432/ternava_restore" \
  --uploads-dir /tmp/ternava-restore-uploads
```

Yang diverifikasi (semua harus `OK`, kalau tidak exit 1):

1. **row-count** — jumlah baris tiap tabel == manifest.
2. **foreign-key** — 0 baris orphan (daily_records/farms, feed_balances/feed_types, memberships/users, task_runs/task_templates).
3. **ledger** — `sum(feed_balances.quantity_kg)` == manifest (ledger = saldo).
4. **logins** — `count(users where active)` == manifest.
5. **file-acl** — tidak ada file private dengan bit group/world (harus 0600, direktori 0700).
6. **journal** — jumlah `audit_events.action = 'retention.deletion'` == manifest (AC-46).
7. **rto** — elapsed <= 4 jam.
8. **rpo** — umur backup <= 24 jam.

### Menerapkan ulang jurnal penghapusan (AC-46)

Saat restore, `restore.sh` mencatat jumlah tombstone `retention.deletion` yang
lebih baru dari timestamp backup. **Tombstone dipertahankan** dan
`idempotency_receipts` **tidak** dibuat ulang — supaya intent lama yang di-replay
tetap ter-dedup dan tidak menggandakan efek bisnis. Jangan pernah mengulang efek
bisnis dengan key baru setelah restore.

## 4. Heartbeat worker/scheduler (AC-45)

```bash
php artisan ternava:heartbeat --role=worker
php artisan ternava:heartbeat --role=scheduler
php artisan ternava:heartbeat --role=worker --json   # cetak dokumen
```

Menulis `backend/storage/app/private/heartbeats/<role>.json` (disk `local`),
berisi `role`, `pid`, `host`, `at`, dan `metrics`: `queue_oldest_seconds`,
`queue_depth`, `failed_jobs`, `push_undelivered`, `push_degraded_devices`.
Dokumen tidak pernah memuat secret.

Worker dan scheduler ditulis terpisah: **worker mati tidak boleh tersembunyi di
balik scheduler yang sehat** (dan sebaliknya). Deployment menulis heartbeat lewat
loop supervisor/cron untuk role worker, dan penjadwal untuk role scheduler:

```cron
* * * * *  php /app/artisan ternava:heartbeat --role=worker  >> /dev/null 2>&1
```

## 5. Health monitor — membedakan jenis gangguan (AC-45)

```bash
python3 ops/health-monitor.py --self-check   # uji ambang (deterministik, exit 0)
python3 ops/health-monitor.py                # ringkas satu baris
python3 ops/health-monitor.py --json         # dokumen status lengkap
```

Ambang (docs/operations-security.md):

| Sinyal | Ambang | Subsystem |
|---|---|---|
| queue tertua | > 5 menit | `queue` |
| heartbeat worker/scheduler | > 3 menit (atau hilang) | `queue` |
| umur backup | > 26 jam | `backup` |
| disk | > 80% | `disk` |
| 5xx | > 5% selama 5 menit | `api` |
| push (undelivered / device disabled) | > 0 | `push` |

Verdict per subsystem memisahkan kegagalan: **API turun** hanya dari rasio 5xx;
**queue** dari umur job dan heartbeat; **backup** dari umur bundle; **push**
dilaporkan `degraded` dan **tidak** menandai API turun (FCM mati tidak
mematikan pencatatan). Field `heartbeat_roles` menunjukkan role mana yang
`ok`/`stale`/`missing`.

```cron
*/2 * * * *  python3 /opt/ternava/ops/health-monitor.py --json >> /var/log/ternava-health.log 2>&1
```

Peringatan owner project bila queue tertua > 5 menit, heartbeat > 3 menit, backup
> 26 jam, disk > 80%, atau 5xx > 5%/5 menit. Primary: pemilik project; secondary:
admin peternakan (nama/kanal/jam respons ditetapkan sebelum pilot — lihat AC-47).

## 6. Hubungan dengan retensi

Jendela retensi (730/180/90/30/14 hari) dan penutupan farm ada di
`retention.md`. Backup disimpan 30 hari sehingga data yang sudah dihapus masih
bisa ada di backup sampai rotasi — karena itu restore **selalu** menerapkan
ulang jurnal `retention.deletion` setelah timestamp backup.

## 7. Bukti (T43, drill nyata)

Drill dijalankan pada data nyata di `ternava_restore` (environment terpisah):

- Backup terenkripsi `<bundle>.tar.gz.enc` (header `Salted__` = AES-256), 0
  string SQL plaintext di bundle.
- Restore: `row-count`/`foreign-key`/`ledger`/`logins`/`file-acl`/`journal`
  semua **OK**; elapsed 0–1 detik (jauh di bawah RTO 4 jam); umur backup detik
  (di bawah RPO 24 jam).
- Mutation check: manifest yang diubah (ledger/journal/farms) membuat drill
  **FAIL** (exit 1) — pemeriksaan benar-benar bisa gagal.
- `health-monitor.py --self-check` menguji 8 kasus termasuk pemisahan role;
  worker heartbeat dihapus → `heartbeat_roles.worker=missing`, `queue=alert`,
  `service=down`, sedangkan API tetap `ok`.
