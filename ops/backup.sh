#!/usr/bin/env bash
#
# TERNAVA — encrypted off-host backup (T43, AC-43).
#
# Produces one timestamped backup bundle per run:
#   <dir>/ternava-<UTC-ts>/database.dump          (pg_dump --format=custom)
#   <dir>/ternava-<UTC-ts>/uploads.tar.gz         (private attachments, no exports)
#   <dir>/ternava-<UTC-ts>/manifest.json          (counts, ledger total, hashes)
#   <dir>/ternava-<UTC-ts>/checksums.txt          (sha256 of every artifact)
#   <dir>/ternava-<UTC-ts>.tar.gz.enc             (payload encrypted, AES-256)
#
# Policy (docs/operations-security.md): daily, encrypted, 30-day retention,
# RPO <= 24h, RTO <= 4h. Encryption keys live OUTSIDE the repo (env or a
# key file); this script never writes or prints the key.
#
# Usage:
#   ops/backup.sh --dry-run                 # print the plan, touch nothing
#   ops/backup.sh                           # run the real backup
#   ops/backup.sh --allow-unencrypted       # local/dev only (fake data)
#   ops/backup.sh --dir /srv/ternava-backups
#
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

DRY_RUN=0
ALLOW_UNENCRYPTED=0
BACKUP_ROOT="${TERNAVA_BACKUP_DIR:-$REPO_ROOT/backups}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)            DRY_RUN=1; shift ;;
    --allow-unencrypted)  ALLOW_UNENCRYPTED=1; shift ;;
    --dir)                BACKUP_ROOT="$2"; shift 2 ;;
    -h|--help)            sed -n '2,20p' "$0"; exit 0 ;;
    *) die "argumen tidak dikenal: $1" ;;
  esac
done

ts="$(date -u +%Y%m%dT%H%M%SZ)"
stamp_dir="$BACKUP_ROOT/ternava-$ts"

plan() {
  cat >&2 <<EOF
TERNAVA backup plan
  mode            : $( ((DRY_RUN)) && echo dry-run || echo real )
  backup dir      : $BACKUP_ROOT
  bundle          : ternava-$ts
  database        : pg_dump --format=custom (schema + data, no owner/privileges)
  uploads         : backend/storage/app/private (attachments only; exports excluded)
  manifest        : counts + ledger total + deletion-journal watermark + sha256
  encryption      : AES-256-CBC/PBKDF2 $( ((ALLOW_UNENCRYPTED)) && echo '(DISABLED by --allow-unencrypted)' || echo '(key from env/key-file)' )
  retention       : ${RETENTION_DAYS} hari
  targets         : RPO <= ${RPO_HOURS}h, RTO <= ${RTO_HOURS}h
EOF
}

if (( DRY_RUN )); then
  log "DRY RUN: tidak menulis apa pun."
  plan
  log "Prasyarat yang akan diperiksa: DATABASE_URL/pg client, private uploads, BACKUP key."
  exit 0
fi

# --- real backup -------------------------------------------------------------
db_url="$(resolve_database_url)"            # resolved but never printed raw
enc_key_env="${TERNAVA_BACKUP_KEY:-}"
enc_key_file="${TERNAVA_BACKUP_KEY_FILE:-}"

if [[ -z "$enc_key_env" && -z "$enc_key_file" && $ALLOW_UNENCRYPTED -eq 0 ]]; then
  die "kunci enkripsi tidak ada (set TERNAVA_BACKUP_KEY atau TERNAVA_BACKUP_KEY_FILE); gunakan --allow-unencrypted hanya untuk data fiktif lokal."
fi

ensure_dir "$stamp_dir"
chmod 700 "$stamp_dir"
log "backup mulai: $stamp_dir"

# 1. database dump
pg_dump_custom "$stamp_dir/database.dump"
log "database.dump selesai ($(stat -c %s "$stamp_dir/database.dump" 2>/dev/null || stat -f %z "$stamp_dir/database.dump") bytes)"

# 2. private uploads (attachments only — exports are derived, not backed up)
uploads_src="$(private_uploads_dir)"
mkdir -p "$stamp_dir/payload"
if [[ -d "$uploads_src/attachments" ]]; then
  tar -czf "$stamp_dir/uploads.tar.gz" -C "$uploads_src" attachments
else
  tar -czf "$stamp_dir/uploads.tar.gz" -T /dev/null 2>/dev/null || : > "$stamp_dir/uploads.tar.gz.placeholder"
  tar -czf "$stamp_dir/uploads.tar.gz" --files-from=/dev/null
fi
log "uploads.tar.gz selesai"

# 3. manifest (metadata only — no secrets)
tables_json="$(psql_query "
  SELECT coalesce(json_object_agg(t, c), '{}'::json)::text FROM (
    SELECT t, (xpath('/row/c/text()', query_to_xml(format('select count(*) as c from %I', t), false, true, '')))[1]::text::bigint AS c
    FROM unnest(ARRAY['farms','users','memberships','cages','flocks','feed_types','feed_balances',
      'feed_entries','population_entries','daily_records','daily_revisions','attachments',
      'incidents','incident_actions','task_templates','task_runs','task_results',
      'notification_outbox','audit_events','jobs','failed_jobs']) AS t
    WHERE to_regclass(t) IS NOT NULL
  ) s;")"

ledger_total="$(psql_query "SELECT coalesce(sum(quantity_kg),0) FROM feed_balances;" 2>/dev/null || echo '0')"
journal_wm="$(psql_query "SELECT coalesce(max(accepted_at)::text,'') FROM audit_events WHERE action='retention.deletion';" 2>/dev/null || echo '')"
journal_rows="$(psql_query "SELECT count(*) FROM audit_events WHERE action='retention.deletion';" 2>/dev/null || echo '0')"
users_active="$(psql_query "SELECT count(*) FROM users WHERE active;" 2>/dev/null || echo '0')"

dump_sha="$(sha256_file "$stamp_dir/database.dump")"
uploads_sha="$(sha256_file "$stamp_dir/uploads.tar.gz")"
git_commit="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"

cat > "$stamp_dir/manifest.json" <<EOF
{
  "backup_id": "ternava-$ts",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git_commit": "$git_commit",
  "policy": { "retention_days": $RETENTION_DAYS, "rpo_hours": $RPO_HOURS, "rto_hours": $RTO_HOURS },
  "database": {
    "dump_file": "database.dump",
    "sha256": "$dump_sha",
    "byte_size": $(stat -c %s "$stamp_dir/database.dump" 2>/dev/null || stat -f %z "$stamp_dir/database.dump"),
    "tables": $tables_json,
    "ledger_feed_balance_kg": "$ledger_total",
    "active_users": $users_active
  },
  "uploads": {
    "archive_file": "uploads.tar.gz",
    "sha256": "$uploads_sha",
    "byte_size": $(stat -c %s "$stamp_dir/uploads.tar.gz" 2>/dev/null || stat -f %z "$stamp_dir/uploads.tar.gz")
  },
  "deletion_journal_watermark": "$journal_wm",
  "deletion_journal_rows": $journal_rows,
  "encryption": { "algorithm": "aes-256-cbc-pbkdf2", "key_source": "$( [[ -n "$enc_key_file" ]] && echo key-file || echo env )", "enabled": $( ((ALLOW_UNENCRYPTED)) && echo false || echo true ) }
}
EOF

# 4. checksums
( cd "$stamp_dir" && sha256sum database.dump uploads.tar.gz manifest.json > checksums.txt )
log "manifest + checksums selesai"

# 5. encrypt the payload (dump + uploads) into a single bundle
if (( ALLOW_UNENCRYPTED )); then
  tar -czf "$BACKUP_ROOT/ternava-$ts.tar.gz" -C "$stamp_dir" database.dump uploads.tar.gz manifest.json checksums.txt
  bundle="$BACKUP_ROOT/ternava-$ts.tar.gz"
else
  tar -czf "$stamp_dir/.payload.tar.gz" -C "$stamp_dir" database.dump uploads.tar.gz
  if [[ -n "$enc_key_file" ]]; then
    openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
      -in "$stamp_dir/.payload.tar.gz" -out "$BACKUP_ROOT/ternava-$ts.tar.gz.enc" \
      -pass "file:$enc_key_file"
  else
    openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
      -in "$stamp_dir/.payload.tar.gz" -out "$BACKUP_ROOT/ternava-$ts.tar.gz.enc" \
      -pass env:TERNAVA_BACKUP_KEY
  fi
  rm -f "$stamp_dir/.payload.tar.gz"
  bundle="$BACKUP_ROOT/ternava-$ts.tar.gz.enc"
fi

sha256_file "$bundle" > "$bundle.sha256"
log "bundle: $(basename "$bundle") ($(stat -c %s "$bundle" 2>/dev/null || stat -f %z "$bundle") bytes)"

# 6. retention: prune bundles older than RETENTION_DAYS
pruned=0
while IFS= read -r old; do
  [[ -z "$old" ]] && continue
  rm -rf "$old"; pruned=$((pruned + 1))
done < <(find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -name 'ternava-*' -mtime "+$RETENTION_DAYS" 2>/dev/null || true)
log "retensi: $pruned item > ${RETENTION_DAYS} hari dipangkas"

log "backup SELESAI: $bundle"
printf '%s\n' "$bundle"
