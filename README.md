# TERNAVA — Planning MVP Ayam Petelur

**Planning saja, 1 Oktober 2026.** Spesifikasi beserta AM-01/02 diterima melalui D-011. Pengguna meminta cukup sampai planning melalui D-012. Aplikasi, scaffold dan deployment belum dimulai.

- [Ringkasan hasil dan urutan kerja](docs/planning-status.md)
- [Rencana implementasi — 46 task](docs/superpowers/plans/2026-10-01-ternava-mvp.md)
- [Spesifikasi — 47 acceptance criteria](docs/superpowers/specs/2026-10-01-ternava-design.md)
- [Handoff kandidat dan readiness](HANDOFF.candidate.md)
- [Brief](docs/brief.md), [keputusan](docs/decisions.md), [rulings](docs/planning-rulings.md)
- [Desain](DESIGN.md), [24 layar](docs/flows-and-screens.md), [preview](preview/index.html)
- [Arsitektur](docs/architecture.md), [API/sync](docs/api-sync.md), [operasi](docs/operations-security.md)
- [OpenAPI](contracts/openapi.json), [schema](contracts/schema.json), [diagram](docs/diagrams/README.md)

Paket planning terbaru sudah disalin ke root pilihan pengguna, `/mnt/data/porto/ternava`, setelah akses tulis diberikan. Versi dokumen sebelumnya dibackup; riwayat brainstorming tetap disimpan. Eksekusi aplikasi belum dimulai.

Periksa dokumen: `bash scripts/local-ci.sh --planning` dan `python3 scripts/check_plan.py`. Hasil ini tidak membuktikan native app, concurrency server, release, load atau restore. Lihat [bukti finalisasi](docs/evidence/planning-finalization.json).
