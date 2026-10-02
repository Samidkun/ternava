# Runbook — TERNAVA (developer)

Topologi, backup/restore, SLO, alert, rollback dan gate data nyata: `../operations-security.md`.
Rancangan tetap; command di bawah divalidasi di environment terpisah, bukan dikarang.

## Start / migrate / worker

```bash
docker compose up -d postgres          # PostgreSQL 18, 127.0.0.1:5432
cd backend && php artisan migrate       # skema (26 tabel logis)
docker compose up -d api worker scheduler
```

- `api` bind `127.0.0.1:8080`; health `/health/live` (proses) dan `/health/ready` (DB + storage private).
- `worker` = `php artisan queue:work`; `scheduler` = `php artisan schedule:work`.

## Retensi

`php artisan ternava:retention` — jendela 730/180/90/30/14 hari; jurnal
penghapusan di `audit_events.action='retention.deletion'`. Detail: `retention.md`.

## Backup & restore

```bash
bash ops/backup.sh --dry-run                     # smoke test, tidak menulis
bash ops/backup.sh --dir /srv/ternava-backups    # harian, terenkripsi, retensi 30 hari
bash ops/restore.sh --verify-isolated --manifest <manifest.json> --isolated-db-url <url>
```

Kunci enkripsi dari `TERNAVA_BACKUP_KEY[_FILE]` (di luar Git). Detail + drill
nyata: `restore.md`.

## Heartbeat & health monitor

```bash
php artisan ternava:heartbeat --role=worker      # juga scheduler
python3 ops/health-monitor.py --self-check       # uji ambang
python3 ops/health-monitor.py --json             # status per subsystem
```

Memisahkan kegagalan API / queue / backup / push. Ambang: queue 5 mnt,
heartbeat 3 mnt, backup 26 jam, disk 80%, 5xx 5%/5 mnt.

## Gate lokal

```bash
bash scripts/local-ci.sh --planning   # gate dokumen/kontrak saja
bash scripts/local-ci.sh --full       # + gitleaks, flutter, backend, audit, build
```

Toolchain terkunci: Flutter 3.47.4, PHP 8.5.x, Docker 29.x (lihat `docs/evidence/toolchain.md`).
Lokasi secrets: file/env runtime di luar Git (`APP_KEY`, kredensial DB, kunci backup, FCM).
Kontak penanggung jawab & provider/biaya ditetapkan sebelum pilot (AC-47).
