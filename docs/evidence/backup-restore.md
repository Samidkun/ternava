# Evidence — Backup, restore dan metrik gangguan (Task T43)

Tanggal: 2 Oktober 2026
Acceptance: AC-43, AC-45, AC-46
Commit dasar: `0118025` (T42) + working tree T43
Environment: host Linux (2 vCPU / 4 GiB), PostgreSQL 18 (`ternava-postgres-1`, 127.0.0.1:5432),
PHP 8.5.10, OpenSSL, `pg_dump`/`pg_restore`/`psql` 18. Semua nilai kredensial di-redact.

## 1. Verify command (per plan T43)

| Perintah | Hasil | Catatan |
|---|---|---|
| `bash ops/backup.sh --dry-run` | **exit 0** | mencetak rencana (db/uploads/manifest/enkripsi/retensi/RPO-RTO); tidak menulis apa pun |
| `bash ops/restore.sh --verify-isolated` (tanpa argumen) | **exit 2** | fail-closed: "butuh manifest backup + isolated database" — sesuai ekspektasi plan |
| `python3 ops/health-monitor.py --self-check` | **exit 0** | `SELF-CHECK: PASS` — 8 kasus ambang, termasuk pemisahan role |

## 2. Backup nyata (AC-43)

```
$ TERNAVA_BACKUP_KEY=<hex> bash ops/backup.sh --dir /tmp/ternava-backups
backup mulai: /tmp/ternava-backups/ternava-20261002T071916Z
database.dump selesai (86735 bytes)
uploads.tar.gz selesai
manifest + checksums selesai
bundle: ternava-20261002T071916Z.tar.gz.enc (12400 bytes)
retensi: 0 item > 30 hari dipangkas
backup SELESAI: /tmp/ternava-backups/ternava-20261002T071916Z.tar.gz.enc
```

- Bundle terenkripsi: 16 byte pertama = `Salted__` (header OpenSSL), artinya
  AES-256-CBC/PBKDF2 aktif. `grep -c 'CREATE TABLE' bundle` = **0** (tidak ada SQL plaintext).
- Manifest nyata (angka dari database hidup): `farms=1 users=1 memberships=1 feed_types=1
  feed_balances=1 attachments=1 audit_events=1`; `ledger_feed_balance_kg=300.00`;
  `active_users=1`; `deletion_journal_watermark=2026-10-02 07:16:53+00`;
  `deletion_journal_rows=1`; `git_commit=011802564351aa75fba6b1535f01d3547d0f831e`.
- Kunci enkripsi **tidak** ditulis ke manifest/checksum/log; hanya
  `key_source=env` yang tercatat.

## 3. Restore drill ke environment terpisah (AC-43)

Database terisolasi `ternava_restore` dibuat terpisah dari `ternava`.

```
$ bash ops/restore.sh --verify-isolated \
    --manifest /tmp/ternava-backups/ternava-20261002T071916Z/manifest.json \
    --isolated-db-url postgresql://ternava:***@127.0.0.1:5432/ternava_restore \
    --uploads-dir /tmp/ternava-restore-uploads
restore selesai (T1); elapsed=1s
OK   row-count — semua tabel cocok
OK   foreign-key — orphan rows=0
OK   ledger — restored=300.00 manifest=300.00
OK   logins — active_users restored=1 manifest=1
OK   file-acl — files with group/world bits=0 (harus 0)
OK   journal — tombstone retention.deletion restored=1 manifest=1 (dedup receipt tidak dibuat ulang)
OK   rto — elapsed=1s target<=14400s
OK   rpo — backup age=1s target<=86400s
RESTORE DRILL: PASS
```

Verifikasi independen (psql langsung ke `ternava_restore`):

```
farms=1 ledger=300.00 tombstones=1 receipts=0
```

- File private terpulihkan: `attachments/drill.jpg` mode **600**, isi utuh
  (`drill-photo-bytes`), direktori mode 700.
- Ledger cocok dengan sumber: `feed_balances.id=5555…, quantity_kg=300.00` di
  DB hidup **dan** di DB terpulihkan (identik).

### RTO/RPO terukur

- RTO: restore penuh selesai dalam **1 detik** (target <= 4 jam).
- RPO: umur backup saat drill **1 detik** (target <= 24 jam); backup harian
  menjamin kehilangan <= 24 jam.

### Mutation check (bukti pemeriksaan bisa gagal)

Manifest diubah (ledger→999.99, journal_rows→99, farms→42) lalu drill diulang:

```
FAIL row-count — farms=1(want 42)
FAIL ledger — restored=300.00 manifest=999.99
FAIL journal — tombstone retention.deletion restored=1 manifest=99
RESTORE DRILL: FAIL
exit=1
```

Artinya pemeriksaan bukan hiasan: ketidakcocokan nyata menaikkan exit 1.

## 4. Heartbeat & metrik (AC-45)

`php artisan ternava:heartbeat --role=worker --json` (data nyata):

```json
{"role":"worker","pid":508000,"host":"…","at":"2026-10-02T07:20:57Z",
 "app_env":"local","queue_connection":"database",
 "metrics":{"queue_oldest_seconds":0,"queue_depth":0,"failed_jobs":0,
 "push_undelivered":0,"push_degraded_devices":0}}
```

Dokumen ditulis ke `backend/storage/app/private/heartbeats/{worker,scheduler}.json`.
Uji PHPUnit `HeartbeatTest` (**6/6 GREEN**): penulisan per role, penolakan role
tidak valid, hitung `jobs`/`failed_jobs` terpisah, push undelivered sebagai sinyal
terpisah, dan dokumen **tidak** memuat nilai password DB.

### Health monitor — gangguan dibedakan

```
$ python3 ops/health-monitor.py            # kondisi sehat
service=up api=ok queue=ok backup=ok push=ok

$ # worker heartbeat dihapus (simulasi worker mati)
service=down | roles={'scheduler':'ok','worker':'missing'} | alerts=['heartbeat.worker']
```

- API hanya `alert` dari rasio 5xx; queue dari umur job/heartbeat; backup dari
  umur bundle; push dilaporkan `degraded` **tanpa** menandai API turun.
- `heartbeat_roles` membuktikan worker mati tidak tersembunyi di balik scheduler
  yang sehat.

### Ambang (sinkron docs/operations-security.md)

queue tertua > 5 menit · heartbeat > 3 menit · backup > 26 jam · disk > 80% ·
5xx > 5%/5 menit · SLO 99,5% bulanan (diukur setelah pilot berjalan).

## 5. Batasan jujur (tidak diklaim lulus)

- **Off-host nyata & rotasi 30 hari** belum dibuktikan di server terpisah —
  drill dijalankan lokal dengan data nyata pada volume `/tmp`; jadwal cron
  off-host dan pemindahan ke host berbeda menunggu infrastruktur pilot.
- **SLO 99,5%** belum terukur: butuh pilot berjalan + probe eksternal; dokumen
  ini hanya menyiapkan metrik/probe, bukan bukti pencapaian.
- **Alert nyata (email/SMS/pager)** belum dikirim — monitor hanya menulis status
  dan exit code; kanal/kontak penanggung jawab ditetapkan sebelum pilot (AC-47).
- **Kunci enkripsi** pada drill ini ephemeral (dibuat per-run, tidak disimpan);
  produksi memakai `TERNAVA_BACKUP_KEY_FILE` dari secret manager di luar Git.
