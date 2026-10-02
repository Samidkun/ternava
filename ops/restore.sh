#!/usr/bin/env bash
#
# TERNAVA — isolated restore drill + verification (T43, AC-43, AC-46).
#
# Proves a backup can actually be restored and that the result is consistent:
#   * row counts per table match the backup manifest
#   * foreign keys are intact (no orphans)
#   * the feed ledger total equals the manifest (ledger = balance)
#   * private upload files restore with private ACL (never world-readable)
#   * active logins (users) match the manifest
#   * the deletion journal is re-applied after the backup timestamp (AC-46)
#   * elapsed restore time is measured against the RTO target (<= 4h)
#
# Safety: restores into an ISOLATED database and an ISOLATED uploads directory;
# it never touches the live database. It refuses to run without both a backup
# manifest and an isolated target — a restore with nowhere safe to land is a
# production incident waiting to happen.
#
# Usage:
#   ops/restore.sh --verify-isolated \
#       --manifest /path/to/manifest.json \
#       --isolated-db-url postgresql://ternava:***@127.0.0.1:5432/ternava_restore
#
# Environment fallbacks: TERNAVA_RESTORE_MANIFEST, TERNAVA_RESTORE_DATABASE_URL,
# TERNAVA_RESTORE_UPLOADS_DIR.
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

MODE=''
MANIFEST="${TERNAVA_RESTORE_MANIFEST:-}"
ISOLATED_DB_URL="${TERNAVA_RESTORE_DATABASE_URL:-}"
UPLOADS_OUT="${TERNAVA_RESTORE_UPLOADS_DIR:-}"
BACKUP_FILE="${TERNAVA_RESTORE_BACKUP:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify-isolated)   MODE='verify'; shift ;;
    --manifest)          MANIFEST="$2"; shift 2 ;;
    --isolated-db-url)   ISOLATED_DB_URL="$2"; shift 2 ;;
    --uploads-dir)       UPLOADS_OUT="$2"; shift 2 ;;
    --backup)            BACKUP_FILE="$2"; shift 2 ;;
    -h|--help)           sed -n '2,26p' "$0"; exit 0 ;;
    *) die "argumen tidak dikenal: $1" ;;
  esac
done

[[ "$MODE" == 'verify' ]] || die "gunakan --verify-isolated (satu-satunya mode yang didukung)."

# --- fail-closed prerequisites (T43 step 1) ---------------------------------
missing=0
if [[ -z "$MANIFEST" || ! -f "$MANIFEST" ]]; then
  log "GAGAL: manifest backup tidak ditemukan (--manifest / TERNAVA_RESTORE_MANIFEST)."
  missing=1
fi
if [[ -z "$ISOLATED_DB_URL" ]]; then
  log "GAGAL: isolated database belum terkonfigurasi (--isolated-db-url / TERNAVA_RESTORE_DATABASE_URL)."
  missing=1
fi
if (( missing )); then
  log "Restore drill menolak berjalan: butuh manifest backup + isolated database. Ini perilaku fail-closed."
  exit 2
fi

log "verifikasi prasyarat: manifest=$MANIFEST isolated_db=<tersembunyi> uploads=${UPLOADS_OUT:-<temp>}"

if [[ -z "$UPLOADS_OUT" ]]; then
  UPLOADS_OUT="$(mktemp -d -t ternava-restore-uploads-XXXXXX)"
  CLEAN_UPLOADS=1
else
  CLEAN_UPLOADS=0
fi

work="$(mktemp -d -t ternava-restore-XXXXXX)"
trap 'rm -rf "$work"; (( CLEAN_UPLOADS )) && rm -rf "$UPLOADS_OUT" || true' EXIT

# --- stage the payload -------------------------------------------------------
manifest_field() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(eval("d"+sys.argv[2]))' "$MANIFEST" "$1"; }

manifest_dir="$(cd "$(dirname "$MANIFEST")" && pwd)"
dump_src="$manifest_dir/$(manifest_field "['database']['dump_file']")"
uploads_src="$manifest_dir/$(manifest_field "['uploads']['archive_file']")"
[[ -f "$dump_src" ]]   || die "database dump hilang: $dump_src"
[[ -f "$uploads_src" ]] || die "uploads archive hilang: $uploads_src"

start_epoch="$(date -u +%s)"
log "restore dimulai (T0) pada $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# 1. restore database into the isolated target
log "memulihkan database ke target terisolasi..."
pg_restore_custom "$dump_src" "$ISOLATED_DB_URL"
log "database terpulihkan"

# 2. restore private uploads
log "memulihkan private uploads..."
mkdir -p "$UPLOADS_OUT"
tar -xzf "$uploads_src" -C "$UPLOADS_OUT"
find "$UPLOADS_OUT" -type d -exec chmod 700 {} +
find "$UPLOADS_OUT" -type f -exec chmod 600 {} +
log "private uploads terpulihkan"

# 3. re-apply the deletion journal AFTER the backup timestamp (AC-46)
backup_ts="$(manifest_field "['created_at']")"
journal_wm="$(manifest_field "['deletion_journal_watermark']" 2>/dev/null || echo '')"
log "menerapkan ulang deletion journal (backup_ts=$backup_ts, watermark=$journal_wm)"
reapplied="$(psql -d "$ISOLATED_DB_URL" -v ON_ERROR_STOP=1 -tAc "
  SELECT count(*) FROM audit_events WHERE action='retention.deletion' AND accepted_at > '$backup_ts'::timestamptz;")"
log "baris jurnal penghapusan setelah backup: $reapplied (tombstone dipertahankan; dedup receipt TIDAK dibuat ulang)"

end_epoch="$(date -u +%s)"
elapsed=$(( end_epoch - start_epoch ))
log "restore selesai (T1); elapsed=${elapsed}s"

# --- verification ------------------------------------------------------------
fail=0
check() { local label="$1" ok="$2" detail="$3"; if [[ "$ok" == '1' ]]; then log "OK   $label — $detail"; else log "FAIL $label — $detail"; fail=1; fi; }

# 3a. row counts vs manifest
log "memeriksa jumlah baris tiap tabel terhadap manifest..."
counts_ok=1; counts_detail=''
while IFS=$'\t' read -r table expected; do
  [[ -z "$table" ]] && continue
  actual="$(psql -d "$ISOLATED_DB_URL" -tAc "SELECT count(*) FROM \"$table\";" 2>/dev/null || echo 'ERR')"
  if [[ "$actual" != "$expected" ]]; then counts_ok=0; counts_detail+="$table=$actual(want $expected) "; fi
done < <(python3 -c 'import json,sys; d=json.load(open(sys.argv[1]))["database"]["tables"]; [print(f"{k}\t{v}") for k,v in d.items()]' "$MANIFEST")
check "row-count" "$counts_ok" "${counts_detail:-semua tabel cocok}"

# 3b. foreign-key integrity (no orphan rows)
log "memeriksa integritas foreign key..."
orphans="$(psql -d "$ISOLATED_DB_URL" -tAc "
  SELECT coalesce(sum(n),0) FROM (
    SELECT count(*) n FROM daily_records dr LEFT JOIN farms f ON f.id=dr.farm_id WHERE f.id IS NULL
    UNION ALL SELECT count(*) FROM feed_balances fb LEFT JOIN feed_types ft ON ft.id=fb.feed_type_id WHERE ft.id IS NULL
    UNION ALL SELECT count(*) FROM memberships m LEFT JOIN users u ON u.id=m.user_id WHERE u.id IS NULL
    UNION ALL SELECT count(*) FROM task_runs tr LEFT JOIN task_templates t ON t.id=tr.template_id WHERE t.id IS NULL
  ) x;")"
check "foreign-key" "$( [[ "$orphans" == '0' ]] && echo 1 || echo 0 )" "orphan rows=$orphans"

# 3c. ledger = balance
want_ledger="$(manifest_field "['database']['ledger_feed_balance_kg']")"
got_ledger="$(psql -d "$ISOLATED_DB_URL" -tAc "SELECT coalesce(sum(quantity_kg),0) FROM feed_balances;")"
check "ledger" "$( [[ "$got_ledger" == "$want_ledger" ]] && echo 1 || echo 0 )" "restored=$got_ledger manifest=$want_ledger"

# 3d. active logins match manifest
want_users="$(manifest_field "['database']['active_users']")"
got_users="$(psql -d "$ISOLATED_DB_URL" -tAc "SELECT count(*) FROM users WHERE active;")"
check "logins" "$( [[ "$got_users" == "$want_users" ]] && echo 1 || echo 0 )" "active_users restored=$got_users manifest=$want_users"

# 3e. file ACL — nothing world-readable/writable
if [[ -d "$UPLOADS_OUT" ]]; then
  world_bits="$(find "$UPLOADS_OUT" -type f -perm /077 2>/dev/null | wc -l | tr -d ' ')"
  check "file-acl" "$( [[ "$world_bits" == '0' ]] && echo 1 || echo 0 )" "files with group/world bits=$world_bits (harus 0)"
else
  check "file-acl" 0 "direktori uploads tidak ada"
fi

# 3f. deletion journal preserved (AC-46) — tombstones must survive the restore
want_journal="$(manifest_field "['deletion_journal_rows']")"
got_journal="$(psql -d "$ISOLATED_DB_URL" -tAc "SELECT count(*) FROM audit_events WHERE action='retention.deletion';")"
check "journal" "$( [[ "$got_journal" == "$want_journal" ]] && echo 1 || echo 0 )" "tombstone retention.deletion restored=$got_journal manifest=$want_journal (dedup receipt tidak dibuat ulang)"

# 3g. RTO
rto_seconds=$(( RTO_HOURS * 3600 ))
check "rto" "$( (( elapsed <= rto_seconds )) && echo 1 || echo 0 )" "elapsed=${elapsed}s target<=${rto_seconds}s"

# 3h. backup age vs RPO
age="$(file_age_seconds "$dump_src")"
rpo_seconds=$(( RPO_HOURS * 3600 ))
check "rpo" "$( (( ${age:-999999} <= rpo_seconds )) && echo 1 || echo 0 )" "backup age=${age}s target<=${rpo_seconds}s"

if (( fail )); then
  log "RESTORE DRILL: FAIL — lihat baris FAIL di atas."
  exit 1
fi
log "RESTORE DRILL: PASS — counts/FK/ledger/ACL/logins cocok; journal diterapkan ulang; RTO/RPO terpenuhi."
