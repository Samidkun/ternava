#!/usr/bin/env bash
# Shared helpers for the TERNAVA backup/restore tooling (T43).
#
# Sourced, never executed. Provides logging, redaction, config loading and the
# single place where credentials are read from the environment (never argv, so
# they never show up in `ps`). Every value printed through here is passed
# through `redact` first.
set -euo pipefail

OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$OPS_DIR/.." && pwd)"

# --- fixed policy constants (docs/operations-security.md) ---------------------
RETENTION_DAYS=30                 # off-host copies kept at most 30 days (RPO context)
RPO_HOURS=24                      # max tolerable data loss window
RTO_HOURS=4                       # max tolerated restore time
HEARTBEAT_STALE_SECONDS=180       # 3 min -> heartbeat alert
QUEUE_OLDEST_SECONDS=300          # 5 min -> queue alert
BACKUP_AGE_SECONDS=93600          # 26 h  -> backup age alert
DISK_PERCENT_LIMIT=80             # >80% -> disk alert
FIVEXX_PERCENT_LIMIT=5            # >5% over 5 min -> 5xx alert
SLO_TARGET_PERCENT='99.5'         # monthly API SLO, measured after the pilot runs

log()  { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
die()  { log "FATAL: $*"; exit 1; }

# Redact credential-ish keys from any line before it is printed or logged.
# Matches KEY=value for keys containing PASSWORD/PASSWD/SECRET/TOKEN/KEY/URL and
# the postgres:// userinfo form user:password@host.
redact() {
  sed -E \
    -e 's#(://[^:/@[:space:]]+:)[^@[:space:]]#\1***#g' \
    -e 's#(([A-Za-z0-9_]*(PASSWORD|PASSWD|SECRET|TOKEN|APIKEY|API_KEY|APP_KEY|CREDENTIAL)[A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*)[^[:space:]]+#\1***#gI'
}

# Load DATABASE_URL / PGHOST / ... from backend/.env when present, without
# exporting the whole file into logs. Only DB_* and DATABASE_URL are honoured.
load_env() {
  local env_file="${TERNAVA_ENV_FILE:-$REPO_ROOT/backend/.env}"
  [[ -f "$env_file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    case "$line" in
      DB_CONNECTION=*|DB_HOST=*|DB_PORT=*|DB_DATABASE=*|DB_USERNAME=*|DB_PASSWORD=*|DATABASE_URL=*)
        # shellcheck disable=SC2163
        export "$line"
        ;;
    esac
  done < "$env_file"
  : "${DB_PORT:=5432}"
  if [[ -z "${DATABASE_URL:-}" && -n "${DB_HOST:-}" && -n "${DB_USERNAME:-}" ]]; then
    local scheme='postgresql'
    DATABASE_URL="${scheme}://${DB_USERNAME}:${DB_PASSWORD:-}@${DB_HOST}:${DB_PORT}/${DB_DATABASE:-ternava}"
  fi
}

# Return DATABASE_URL, preferring an explicit environment value over .env.
resolve_database_url() {
  if [[ -z "${DATABASE_URL:-}" ]]; then load_env; fi
  [[ -n "${DATABASE_URL:-}" ]] || die "DATABASE_URL tidak terkonfigurasi (set env atau backend/.env)."
  printf '%s' "$DATABASE_URL"
}

# Run pg_dump/pg_restore/psql, transparently through the postgres container when
# the host client tools are not installed. The DATABASE_URL is resolved inside
# the container from its own env, so no credential is passed on the host argv.
# Usage: pg_backend <probe|dump|restore|psql> [args...]
pg_container() {
  local name
  name="$(docker ps --format '{{.Names}}' 2>/dev/null | grep -m1 'postgres' || true)"
  [[ -n "$name" ]] || return 1
  printf '%s' "$name"
}

have_host_pg() { command -v "$1" >/dev/null 2>&1; }

# Convert an external DATABASE_URL into the libpq URL the container can use:
# the container reaches the host postgres through the host gateway.
container_database_url() {
  local url="$1" host
  host="$(printf '%s' "$url" | sed -E 's#^[a-zA-Z0-9]+://([^:/@]*:)?[^@]*@##; s#/.*$##; s#:[0-9]+$##')"
  if [[ "$host" == "127.0.0.1" || "$host" == "localhost" ]]; then
    printf '%s' "$url" | sed -E 's#(://[^@]*@)(127\.0\.0\.1|localhost)#\1host.docker.internal#'
  else
    printf '%s' "$url"
  fi
}

# Verify the tooling can reach a directory safely.
ensure_dir() { mkdir -p "$1" || die "tidak dapat membuat direktori $1"; }

# Compute a hex sha256 of a file (path printed separately, never embedded raw).
sha256_file() { sha256sum "$1" | awk '{print $1}'; }

# Age of a file in seconds since mtime; empty when the file is missing.
file_age_seconds() {
  local f="$1"
  [[ -e "$f" ]] || { printf ''; return 0; }
  local now mtime
  now="$(date -u +%s)"
  mtime="$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null)"
  printf '%s' "$(( now - mtime ))"
}

# --- database access ---------------------------------------------------------
# Prefer host client tools (they reach the published 127.0.0.1:5432 port);
# otherwise run inside the running postgres container using ITS OWN credentials
# so no secret ever appears on a host argv or in `ps`.

# True when the host has working psql + pg_dump.
db_tools_local() { have_host_pg psql && have_host_pg pg_dump; }

# psql_query "SQL" -> tab-separated rows, no header.
psql_query() {
  local sql="$1"
  if db_tools_local; then
    psql "$(resolve_database_url)" -v ON_ERROR_STOP=1 -tAc "$sql"
  else
    local c; c="$(pg_container)" || die "psql/pg_dump tidak tersedia dan container postgres tidak ditemukan."
    docker exec "$c" sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 -tAc "$1"' _ "$sql"
  fi
}

# pg_dump_custom <output-file>
pg_dump_custom() {
  local out="$1"
  if db_tools_local; then
    pg_dump "$(resolve_database_url)" --format=custom --no-owner --no-privileges --file "$out"
  else
    local c; c="$(pg_container)" || die "pg_dump tidak tersedia dan container postgres tidak ditemukan."
    docker exec "$c" sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --no-owner --no-privileges' > "$out"
  fi
}

# pg_restore_custom <input-file> <target-database-url>
pg_restore_custom() {
  local in="$1" url="$2"
  if have_host_pg pg_restore; then
    pg_restore --clean --if-exists --no-owner --no-privileges --dbname "$url" "$in"
  else
    die "pg_restore tidak tersedia di host; restore drill memerlukan client tools."
  fi
}

# Private uploads directory inside the Laravel app.
private_uploads_dir() { printf '%s/backend/storage/app/private' "$REPO_ROOT"; }
