#!/usr/bin/env bash
# Planning success is distinct from application readiness.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mode="${1:---full}"
[[ "$mode" == --planning || "$mode" == --full ]] || { echo 'Use --planning or --full'; exit 2; }
python3 scripts/check_contracts.py
python3 scripts/generate_diagrams.py --check
python3 scripts/check_secrets.py
if [[ "$mode" == --planning ]]; then
  echo 'PLANNING CHECKS PASS; application/native/security gates NOT RUN.'
  exit 0
fi
for file in mobile/pubspec.yaml mobile/pubspec.lock backend/composer.json backend/composer.lock backend/artisan toolchain/flutter-version.txt; do
  [[ -f "$file" ]] || { echo "NOT READY: missing $file; full gates cannot run."; exit 1; }
done
command -v flutter >/dev/null || { echo 'NOT READY: Flutter SDK missing'; exit 1; }
command -v composer >/dev/null || { echo 'NOT READY: Composer missing'; exit 1; }
command -v gitleaks >/dev/null || { echo 'NOT READY: gitleaks required for tree and history'; exit 1; }
gitleaks dir . --redact --no-banner
gitleaks git . --redact --no-banner
[[ "$(flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')" == "$(cat toolchain/flutter-version.txt)" ]] || { echo 'NOT READY: Flutter differs from locked version'; exit 1; }
(
  cd mobile
  flutter pub get --enforce-lockfile
  dart format --output=none --set-exit-if-changed lib test integration_test
  flutter analyze --fatal-infos
  flutter test
  [[ -f ../scripts/audit_mobile_dependencies.py ]] || { echo 'NOT READY: mobile dependency/SBOM audit missing'; exit 1; }
  python3 ../scripts/audit_mobile_dependencies.py
  flutter build apk --debug
)
(
  cd backend
  composer install --no-interaction --prefer-dist
  vendor/bin/pint --test
  vendor/bin/phpstan analyse
  php artisan test
  composer audit --no-interaction
)
echo 'FULL LOCAL BUILD GATES PASS; native device/UAT/load/restore/signed release checks remain separate.'
