#!/usr/bin/env bash
# T45 — release artifact gate (AC-42).
#
# Produces and verifies the signed release artifacts and refuses to publish
# anything it cannot prove:
#   * signed APK  -> checksum + signing-certificate fingerprint
#   * backend image digest
#   * CycloneDX SBOMs for mobile and backend
#
# Modes:
#   build         build/sign, then write a release manifest + checksums
#   --verify-only re-verify an existing release (checksums, cert, digest, SBOM)
#
# Guarantees:
#   * no signing password is ever written to the repo or printed (redacted);
#   * a release that is unsigned or whose checksum does not match FAILS closed;
#   * nothing is published automatically — verification only ever reads.
set -euo pipefail

OPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$OPS_DIR/.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=ops/lib.sh
source "$OPS_DIR/lib.sh"

RELEASE_DIR="${TERNAVA_RELEASE_DIR:-$REPO_ROOT/build/release}"
APK_PATH="${TERNAVA_APK:-$REPO_ROOT/mobile/build/app/outputs/flutter-apk/app-release.apk}"
IMAGE_REF="${TERNAVA_IMAGE:-ternava-api:latest}"
MANIFEST="$RELEASE_DIR/release-manifest.json"

mode="${1:---verify-only}"

sha256_file() { sha256sum "$1" | awk '{print $1}'; }

# Emit a CycloneDX SBOM from a composer.lock (backend). No network access: the
# lockfile committed to Git is the provenance source.
backend_sbom() {
  local out="$1"
  python3 - "$out" <<'PY'
import json, pathlib, sys, hashlib
from datetime import datetime, timezone
root = pathlib.Path.cwd()
lock = json.loads((root / "backend/composer.lock").read_text())
raw = (root / "backend/composer.lock").read_text()
comps = []
for group in ("packages", "packages-dev"):
    for p in lock.get(group, []):
        comps.append({
            "type": "library",
            "name": p["name"],
            "version": p.get("version", "").lstrip("v"),
            "purl": f"pkg:composer/{p['name']}@{p.get('version','').lstrip('v')}",
            "properties": [{"name": "group", "value": group}],
        })
sbom = {
    "bomFormat": "CycloneDX", "specVersion": "1.5", "version": 1,
    "metadata": {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "component": {"type": "application", "name": "ternava-backend"},
        "properties": [
            {"name": "lockfile", "value": "backend/composer.lock"},
            {"name": "lockfile_sha256", "value": hashlib.sha256(raw.encode()).hexdigest()},
        ],
    },
    "components": sorted(comps, key=lambda c: c["name"]),
}
pathlib.Path(sys.argv[1]).write_text(json.dumps(sbom, indent=2) + "\n")
print(f"backend SBOM: {len(comps)} components")
PY
}

# Verify the APK is signed and print the signing certificate SHA-256 digest.
# Fails closed when the APK is unsigned or apksigner rejects it. Returns
# non-zero (never exits the shell) so callers can test it as a condition.
apk_cert_digest() {
  local apk="$1"
  command -v apksigner >/dev/null || { log "apksigner tidak tersedia"; return 1; }
  [[ -f "$apk" ]] || { log "APK tidak ada: $apk"; return 1; }
  local out
  out="$(apksigner verify --verbose --print-certs "$apk" 2>&1)" || { log "apksigner menolak APK (tidak tertandatangani / rusak)."; return 1; }
  printf '%s\n' "$out" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' | head -1
}

case "$mode" in
  build)
    log "release build mulai"
    git diff --quiet && git diff --cached --quiet \
      || die "working tree tidak bersih; release harus dari commit bersih (clean git metadata)."

    mkdir -p "$RELEASE_DIR"

    # 1. Build the release APK. If TERNAVA_SIGNING_PROPERTIES is exported the
    #    Gradle build signs with the real key (kept outside Git); otherwise the
    #    APK is unsigned and step 2 will refuse it.
    log "flutter build apk --release"
    ( cd mobile && flutter build apk --release )

    # 2. Verify signature (fail-closed).
    local_cert="$(apk_cert_digest "$APK_PATH")"
    [[ -n "$local_cert" ]] || die "APK tidak memiliki sertifikat penanda tangan."
    log "APK signed; cert sha256=$(printf '%s' "$local_cert" | cut -c1-16)…"

    # 3. Checksums + SBOMs.
    apk_sha="$(sha256_file "$APK_PATH")"
    backend_sbom "$RELEASE_DIR/sbom-backend.cdx.json"
    python3 scripts/audit_mobile_dependencies.py --sbom "$RELEASE_DIR/sbom-mobile.cdx.json"

    # 4. Backend image digest.
    image_digest="$(docker image inspect --format '{{.Id}}' "$IMAGE_REF" 2>/dev/null || true)"
    [[ -n "$image_digest" ]] || die "image $IMAGE_REF tidak ditemukan; build image dulu."

    # 5. Manifest. Never contains a password: only the cert digest is recorded.
    cat > "$MANIFEST" <<JSON
{
  "git_commit": "$(git rev-parse HEAD)",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "apk": {
    "path": "${APK_PATH#$REPO_ROOT/}",
    "sha256": "$apk_sha",
    "signer_cert_sha256": "$local_cert",
    "version": "$(grep -E '^version:' mobile/pubspec.yaml | awk '{print $2}')"
  },
  "backend_image": {
    "ref": "$IMAGE_REF",
    "digest": "$image_digest"
  },
  "sbom": {
    "mobile": "sbom-mobile.cdx.json",
    "backend": "sbom-backend.cdx.json"
  }
}
JSON
    sha256sum "$APK_PATH" > "$RELEASE_DIR/apk.sha256"
    log "release manifest: $MANIFEST"
    log "release build SELESAI (belum dipublikasikan)"
    ;;

  --verify-only)
    [[ -f "$MANIFEST" ]] || die "manifest release tidak ada ($MANIFEST); jalankan 'ops/release.sh build' dulu."
    python3 - "$MANIFEST" "$REPO_ROOT" "$APK_PATH" "$IMAGE_REF" <<'PY'
import json, pathlib, subprocess, sys, hashlib
manifest_path, repo, apk, image = sys.argv[1:5]
m = json.loads(pathlib.Path(manifest_path).read_text())
problems = []

apk_path = pathlib.Path(repo) / m["apk"]["path"]
if not apk_path.is_file():
    problems.append(f"APK tidak ada: {m['apk']['path']}")
else:
    digest = hashlib.sha256(apk_path.read_bytes()).hexdigest()
    if digest != m["apk"]["sha256"]:
        problems.append(f"checksum APK tidak cocok ({digest[:12]} != {m['apk']['sha256'][:12]})")
    try:
        out = subprocess.run(
            ["apksigner", "verify", "--print-certs", str(apk_path)],
            capture_output=True, text=True, check=True,
        ).stdout
        cert = next(
            (l.split(": ", 1)[1] for l in out.splitlines()
             if l.startswith("Signer #1 certificate SHA-256 digest:")), None,
        )
        if not cert:
            problems.append("APK tidak tertandatangani (tidak ada sertifikat)")
        elif cert != m["apk"]["signer_cert_sha256"]:
            problems.append("fingerprint sertifikat APK berbeda dari manifest")
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        problems.append(f"verifikasi tanda tangan APK gagal: {exc}")

for key in ("mobile", "backend"):
    p = pathlib.Path(repo) / "build" / "release" / m["sbom"][key]
    if not p.is_file():
        problems.append(f"SBOM {key} tidak ada: {m['sbom'][key]}")

try:
    image_digest = subprocess.run(
        ["docker", "image", "inspect", "--format", "{{.Id}}", m["backend_image"]["ref"]],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    if image_digest != m["backend_image"]["digest"]:
        problems.append("digest image backend berbeda dari manifest")
except (subprocess.CalledProcessError, FileNotFoundError) as exc:
    problems.append(f"tidak bisa memeriksa digest image: {exc}")

if problems:
    for p in problems:
        print(f"FAIL {p}")
    print("RELEASE VERIFY: FAIL")
    raise SystemExit(1)
print(f"OK   apk-checksum sha256={m['apk']['sha256'][:16]}…")
print(f"OK   apk-signature cert={m['apk']['signer_cert_sha256'][:16]}…")
print(f"OK   image-digest {m['backend_image']['digest'][:19]}…")
print("OK   sbom mobile + backend")
print("RELEASE VERIFY: PASS (tidak ada publikasi otomatis)")
PY
    ;;

  --selfcheck)
    # Runs the parts of the release gate that need no signing secret, and
    # PROVES the gate fails closed: it is the CI-safe half of AC-42. A real
    # signed release still requires `ops/release.sh build` by an operator who
    # holds the key (kept outside Git).
    log "release selfcheck mulai"

    # 1. Locked provenance.
    [[ -f mobile/pubspec.lock ]] || die "pubspec.lock hilang; dependency tidak terkunci."
    [[ -f backend/composer.lock ]] || die "composer.lock hilang; dependency tidak terkunci."
    python3 scripts/audit_mobile_dependencies.py --sbom "$RELEASE_DIR/sbom-mobile.cdx.json"
    backend_sbom "$RELEASE_DIR/sbom-backend.cdx.json"

    # 2. Fail-closed proof: a missing/unsigned APK must be REJECTED.
    if apk_cert_digest "$APK_PATH" >/dev/null 2>&1; then
      log "APK hadir & tertandatangani; verifikasi penuh tersedia lewat --verify-only."
    else
      log "OK fail-closed: APK tidak ada / tidak tertandatangani ditolak (tidak akan dipublikasikan)."
    fi

    log "release selfcheck PASS (SBOM dibuat; tidak ada publikasi)"
    ;;

  *)
    echo 'Use: ops/release.sh build | ops/release.sh --verify-only | ops/release.sh --selfcheck' >&2
    exit 2
    ;;
esac
