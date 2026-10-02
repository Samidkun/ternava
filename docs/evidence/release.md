# Evidence — CI, audit dan artefak release (Task T45)

Tanggal: 2 Oktober 2026
Acceptance: AC-42
Commit dasar: `98403ea` (T44) + working tree T45
Environment: host Linux 12 vCPU / 15 GiB; Flutter 3.47.4 / Dart 3.13.3; PHP 8.5.10;
Composer 2.10.3; Docker 29.8.1; `apksigner` 0.9; gitleaks. Semua nilai kredensial
di-redact.

## 1. Verify command (per plan T45)

| Perintah | Hasil | Catatan |
|---|---|---|
| `bash scripts/local-ci.sh --full` | lihat §2 | seluruh gate aplikasi (validator/DTO/pint/phpstan/test/audit/scanner) |
| `bash ops/release.sh --verify-only` | **exit 1** tanpa manifest | fail-closed: "manifest release tidak ada" — sesuai ekspektasi |
| `bash ops/release.sh build` | lihat §3 | APK release bertanda tangan + manifest + SBOM |
| `bash ops/release.sh --verify-only` (setelah build) | **exit 0** | checksum + sertifikat + digest + SBOM cocok |
| `bash ops/release.sh --selfcheck` | **exit 0** | varian aman-CI (tanpa rahasia): SBOM + bukti fail-closed |

## 2. Gate lokal penuh (AC-42)

`scripts/local-ci.sh --full` menjalankan, berurutan dan gagal-cepat:

1. `check_contracts.py`, `validate_openapi.py`, `generate_dto.py --check`
   (validator + diff DTO — ditambahkan di T45), `generate_diagrams.py --check`,
   `check_secrets.py` (gitleaks tree + history).
2. Mobile: `flutter pub get --enforce-lockfile`, `dart format --set-exit-if-changed`,
   `flutter analyze --fatal-infos`, `flutter test`, `audit_mobile_dependencies.py`,
   `flutter build apk --debug`.
3. Backend: `composer install`, `pint --test`, `phpstan analyse`, `php artisan test`,
   `composer audit --no-interaction`.

> Catatan perbaikan: gate `dart format` dan `flutter analyze --fatal-infos` awalnya
> **gagal** karena dua hal, keduanya diperbaiki di T45 tanpa mengubah perilaku:
> (1) kode ditulis dengan gaya formatter Dart lama — formatter resmi dijalankan
> (mekanis, hanya whitespace) dan dua `if (...) return false;` diberi blok `{}`
> agar lolos lint; (2) generator DTO memakai arrow body yang dibungkus ulang oleh
> `dart format`, sehingga `generate_dto.py --check` dan `dart format --check`
> bertentangan — generator diubah ke block body dan 125 DTO di-regenerate.

Hasil akhir: **`local-ci.sh --full` PASS** (mobile 93/93, backend 139/139,
pint/phpstan bersih, `composer audit` tanpa advisory, gitleaks tree+history PASS).

## 3. Artefak release bertanda tangan (AC-42)

```
$ TERNAVA_SIGNING_PROPERTIES=~/.ternava/release-signing.properties bash ops/release.sh build
...
APK signed; cert sha256=…
release manifest: build/release/release-manifest.json
release build SELESAI (belum dipublikasikan)
```

- APK release dibangun dengan **kunci rilis asli** yang disimpan **di luar Git**
  (`~/.ternava/release.jks` + `release-signing.properties`, mode 600). Tidak ada
  password yang ditulis ke repo atau dicetak (di-redact).
- Manifest memuat: `git_commit`, `apk.sha256`, `apk.signer_cert_sha256`,
  `backend_image.digest`, dan rujukan SBOM. **Tidak** memuat password.
- SBOM CycloneDX dihasilkan untuk mobile (`pubspec.lock`, 40 komponen) dan backend
  (`composer.lock`, 111 komponen).

### Verifikasi ulang (fail-closed)

```
$ bash ops/release.sh --verify-only
OK   apk-checksum sha256=…
OK   apk-signature cert=…
OK   image-digest sha256:…
OK   sbom mobile + backend
RELEASE VERIFY: PASS (tidak ada publikasi otomatis)
```

### Bukti gerbang benar-benar bisa gagal (mutation check)

| Mutasi | Hasil |
|---|---|
| `--verify-only` tanpa manifest | **exit 1** — "manifest release tidak ada" |
| `--selfcheck` tanpa APK tertandatangani | log "OK fail-closed: APK ... ditolak" |
| checksum APK diubah | `FAIL checksum APK tidak cocok` → `RELEASE VERIFY: FAIL` (exit 1) |
| fingerprint sertifikat di manifest diubah | `FAIL fingerprint sertifikat APK berbeda` → exit 1 |

## 4. CI (`.github/workflows/ci.yml`)

Tiga job:
- `planning-contracts` — `local-ci.sh --planning`.
- `application-gates` — `local-ci.sh --full` (Postgres 18 service).
- `release-artifacts` — build image backend + `ops/release.sh --selfcheck`
  (SBOM, fail-closed, provenance terkunci). Job ini **hanya memverifikasi**;
  publikasi adalah langkah manual terpisah, sehingga gate yang gagal tidak
  bisa mengirim rilis otomatis.

**Branch protection / required checks** (diatur di pengaturan repo GitHub, di luar
file): `planning-contracts`, `application-gates`, `release-artifacts` wajib hijau
sebelum merge ke `main`.

## 5. Batasan jujur (tidak diklaim lulus)

- **CI remote belum pernah dijalankan.** Workflow ditulis dan divalidasi secara
  lokal (YAML parse + langkah-langkahnya diuji via `local-ci.sh --full` dan
  `ops/release.sh --selfcheck`), tetapi **belum** ada bukti run GitHub Actions
  nyata — repo belum di-push ke GitHub dengan runner aktif.
- **Branch protection belum diaktifkan** di server; konfigurasinya didokumentasikan
  di atas, bukan diterapkan.
- **Kunci rilis di mesin ini ephemeral** (dibuat untuk drill, di luar Git).
  Produksi memakai keystore di secret manager/HSM; fingerprint sertifikat nyata
  ditetapkan sebelum pilot (AC-47).
- **Migrasi forward/rollback backup drill**: drill restore T43 sudah ada
  (`docs/evidence/backup-restore.md`); drill migrasi maju→rollback penuh pada
  skema produksi belum dijalankan terhadap data pilot nyata.
- **SBOM** dihasilkan dari lockfile (provenance terkunci), bukan hasil resolusi
  ulang terhadap registry live; tidak ada pemindaian kerentanan (SCA) pihak ketiga.
