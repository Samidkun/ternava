# Runbook — rancangan lokal

Belum ada app/Compose/provider aktif. Topologi, backup/restore, SLO, alert, rollback dan gate data nyata berada di ../operations-security.md. Factory checks: bash scripts/local-ci.sh --planning. Full app checks sengaja gagal bila SDK/app/lockfiles tidak tersedia.

Setelah execution, runbook harus memuat command start/migrate/worker/backup/restore, toolchain dan image digests, lokasi secrets dan kontak penanggung jawab. Validasi command di environment terpisah sebelum pilot; jangan mengarang command untuk services yang belum ada.
