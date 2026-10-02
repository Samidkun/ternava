# TERNAVA — Factory readiness

1 Oktober 2026 · T2 · status **PARTIAL, belum factory-ready**.

Bootstrap satu kali memakai skill [project-bootstrap](/home/samid/.codex/skills/project-bootstrap/SKILL.md), kemudian disesuaikan untuk monorepo Flutter/Laravel. Bootstrap awal mendeteksi stack unknown karena app belum dibuat; ini tidak diartikan stack berhasil diuji. Lighthouse/web E2E tidak berlaku pada native; config Lighthouse contoh dihapus, tidak ada upload preview ke layanan publik. Dependabot memakai pub/mobile dan Composer/backend menurut [referensi resmi GitHub](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference).

| Bagian | Status nyata | Bukti / pekerjaan tersisa |
|---|---|---|
| Kontrak, schema dan AC | Pemeriksaan struktural lulus | 59 operasi, 124 schemas, 26 tabel, 24 layar, 47 AC, 4 contoh valid dan 5 contoh invalid ditolak. Bukan full OpenAPI semantic validation. |
| Diagram | Generated + drift check lulus | ERD, 3 sequence, architecture, 2 user flow; syntax merujuk [Mermaid ERD](https://mermaid.js.org/syntax/entityRelationshipDiagram.html). Render semua diagram belum diperiksa. |
| Secret working tree | gitleaks 8.27.2 lulus | Sekitar 12,65 MB diperiksa, no leaks; environment sample tidak memakai secret nyata. |
| Hook staged/history | 6 kasus synthetic scratch lulus | Placeholder lolos; secret staged yang dibersihkan hanya di disk tetap diblokir; secret di history yang sudah dihapus tetap tertangkap. Bukan history project. |
| Aktivasi hook project | Belum aktif | `git init` gagal read-only saat menulis `.git/hooks`; `core.hooksPath` tidak terpasang. Repository metadata memerlukan akses tulis sebelum execution. Tidak membuat remote/commit/push. |
| Local gate | Planning lulus, full sengaja gagal | `--full` exit 1 karena `mobile/pubspec.yaml` belum ada. Tidak ada klaim lint/test/build aplikasi lulus. |
| Flutter/Dart | Belum tersedia | Exact Flutter stable/Dart/plugin versions dibekukan dan SDK disiapkan sebelum feature code. Tidak mengarang patch latest. |
| Backend/Docker | Rancangan saja | PHP/Composer/Docker tersedia, Laravel app/Compose/migrations/lockfiles belum dibuat. Tidak ada container yang dinyatakan berjalan. |
| CI | YAML/shell parsed, belum dieksekusi remote | Tidak ada Git remote. `application-gates` gagal bila apps/lockfile/toolchain belum ada; planning-job hanya memeriksa artifacts. Workflow/action SHA/scanner/image digest dipin dan dicoba sebelum menjadi required gate. |
| Dependency audit/SBOM/release | Belum dapat dijalankan | Belum ada lockfiles; mobile audit tooling, typedDTO/fullvalidator, native device/load/restore dan signing masuk pekerjaan execution. Debug build bukan signed pilot release. |
| FCM | Belum dikonfigurasi | Backend/Flutter Firebase config dan credential runtime disiapkan setelah project Firebase dipilih; FCM disabled pada rancangan lokal. Inbox tetap dirancang durable. |
| Preview | Evidence baseline + source revision | 260 kombinasi lulus pada baseline terdahulu; AM-01/02 detail baru/edit belum punya render ulang, hanya script syntax/inventory check. Native TalkBack/200% belum diuji. |

Perintah sekarang: `bash scripts/local-ci.sh --planning`. Perintah full: `bash scripts/local-ci.sh --full`; exit gagal saat prasyarat belum ada merupakan hasil yang benar, tidak diubah menjadi skip sukses. Struktur persiapan ini tidak merupakan izin feature execution sebelum spec/plan/HANDOFF direview.

Sebelum feature code: akses metadata Git/hook aktif, exact toolchain/lockfiles, app baseline dan full contract validator tersedia; CI lokal/remote terbukti; dependency/security gates berjalan. Sebelum pilot: semua native/load/restore/release/UAT dan provider/biaya/kontak farm gate dalam operations-security.md selesai.
