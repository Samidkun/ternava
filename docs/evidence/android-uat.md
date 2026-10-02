# Android UAT — T42 (uji native seluruh state dan flow offline)

Tanggal: 2026-10-02
Task: T42 — Uji native seluruh state dan flow offline
Plan: `docs/superpowers/plans/2026-10-01-ternava-mvp.md`
Build commit: `80e7d2e` (`feat: t41 ternava abuse limits retensi dan deletion journal`) + working tree T42
Build varian: **debug** (dibangun terpisah dari release; lihat catatan "Batas").

## Perangkat & toolchain

| Item | Nilai |
|---|---|
| Perangkat | Android Emulator (AVD `ternava35`, device profile `pixel_6`) |
| Model | `sdk_gphone64_x86_64` |
| Manufacturer | Google |
| Device | `emu64xa` |
| Android release | 15 |
| SDK / API level | 35 |
| ABI | `x86_64` |
| Fingerprint | `google/sdk_gphone64_x86_64/emu64xa:15/AE3A.240806.043/12960925:userdebug/dev-keys` |
| Emulator | Android emulator 37.2.12.0 (build_id 16428233) |
| Flutter | 3.47.4 • stable |
| Device id | `emulator-5554` |
| Host | Linux x86_64, `/dev/kvm` tersedia (akselerasi perangkat keras aktif) |

Perintah boot emulator (headless):

```bash
/opt/android-sdk/emulator/emulator -avd ternava35 \
  -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect \
  -no-snapshot -accel on
```

## Cara menjalankan

```bash
cd mobile
# Widget/unit half (host, tanpa perangkat):
flutter analyze
flutter test test/ui/screen_states_test.dart

# Native half (perangkat/emulator):
export ANDROID_SDK_ROOT=/opt/android-sdk
export ANDROID_HOME=/opt/android-sdk
export PATH=/opt/android-sdk/platform-tools:$PATH
flutter test integration_test/operator_flow_test.dart    -d emulator-5554
flutter test integration_test/account_isolation_test.dart -d emulator-5554

# Tangkap screenshot perangkat nyata:
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d emulator-5554
# -> build/uat-screenshots/*.png (disalin ke docs/evidence/screenshots/)
```

## Hasil

### Widget/unit (`mobile/test/ui/screen_states_test.dart`) — PASS 6/6

```
00:00 +0: manifest declares 24 screens and 132 states
00:00 +1: every screen renders every declared state without throwing
00:03 +2: layout survives 320dp width with 200% text scale
00:04 +3: layout survives 414dp width with 200% text scale
00:04 +4: interactive targets meet the 48dp minimum
00:05 +5: reduced motion yields zero-duration theme animations
00:05 +6: All tests passed!
```

- 24 screen / 132 state dari `preview/manifest.json` (source of truth) semuanya
  membangun frame tanpa exception.
- 320dp **dan** 414dp @ teks 200%: tidak ada overflow (AC-40).
- Target sentuh: setiap tombol Material dan InkWell/GestureDetector level-aplikasi
  ≥ 48dp (AC-40).
- Reduced motion: durasi animasi tema = 0 saat `disableAnimations` (AC-40).

### Native (`mobile/integration_test/operator_flow_test.dart`) — PASS 6/6 di `emulator-5554`

```
00:00 +0: catatan offline survive relaunch lalu sync sekali
00:00 +1: timeout setelah commit mempertahankan key dan payload
00:00 +2: teks temuan offline tahan relaunch dan tidak hilang
00:00 +3: 401/403 menghentikan retry, 409/422 minta tinjauan
00:00 +4: daily-form dan sync-center render di perangkat
00:02 +5: layar kritis membangun frame tanpa error di perangkat
00:03 +6: All tests passed!
```

Pemetaan AC: AC-01, AC-10, AC-12, AC-13, AC-19, AC-23, AC-25, AC-39.

### Native (`mobile/integration_test/account_isolation_test.dart`) — PASS 4/4 di `emulator-5554`

```
00:00 +0: logout terkonfirmasi mengunci partisi namun antrean tetap ada
00:00 +1: akun B tidak dapat mendekripsi payload akun A
00:00 +2: lease kedaluwarsa atau jam mundur menghentikan penulisan
00:00 +3: bootstrap tidak menghapus draft/outbox yang belum terkirim
00:01 +4: All tests passed!
```

Pemetaan AC: AC-24, AC-33, AC-34, AC-35.

### Screenshot perangkat nyata

Diambil di `emulator-5554` via `flutter drive` + `takeScreenshot` (bukan mockup):

- `docs/evidence/screenshots/t42-login.png`
- `docs/evidence/screenshots/t42-today.png`
- `docs/evidence/screenshots/t42-daily-form.png`
- `docs/evidence/screenshots/t42-sync-center.png`
- `docs/evidence/screenshots/t42-account.png`

## Temuan nyata yang diperbaiki (bukan di-suppress)

1. **Overflow 320dp @ teks 200%** pada `DropdownButtonFormField` (tanpa
   `isExpanded`) di `access/member_form_screen.dart`, `daily/daily_form_screen.dart`,
   `feed/feed_type_form_screen.dart`, `tasks/task_form_screen.dart`,
   `incidents/incident_list_screen.dart` → ditambah `isExpanded: true`.
2. **Overflow pada `ListTile` trailing** (`today_screen.dart`, `feed_stock_screen.dart`)
   saat teks 200% → trailing direstruktur ke layout vertikal (label teks produksi
   dipertahankan persis).

Perbaikan dilakukan di **kode produksi**, bukan dengan menonaktifkan cek di test.

## Batas & gap jujur (PENDING — tidak diklaim lulus)

- **TalkBack pada perangkat fisik: PENDING.** Emulator di sini tidak punya
  TalkBack + jari manusia untuk memvalidasi urutan baca dan aksi penting. Yang
  bisa diverifikasi otomatis (label, urutan semantik dasar, target 48dp, teks
  200%, reduced motion, kontras) sudah dicakup widget test; sisanya **butuh
  perangkat Android nyata** dan harus dijalankan manual sebelum rilis.
- **True OS process-kill / persistensi on-disk: PENDING.** Lapisan mobile
  saat ini in-memory (tanpa Drift/SQLite on-disk — simplifikasi arsitektur
  pra-eksisting T17–T40). `relaunch()` di `mobile_scenario.dart` memodelkan
  *recovery path* produksi (recoverSending + refresh bootstrap), **bukan**
  pembunuhan proses OS dan **bukan** pembacaan ulang dari disk. Klaim
  "survive relaunch" di sini berarti "survive model recovery", bukan survive
  kill proses nyata.
- **Kamera / storage fault nyata: PENDING.** Tidak ada kamera fisik di
  emulator; jalur unggah foto diuji lewat transport fault, bukan hardware.
- **Kontras 4.5:1: BELUM diaudit otomatis.** Belum ada test kontras otomatis
  di T42; warna tema (primary `#195647` di atas surface `#FFFFFF`, body text
  `#1A2E26`/`#526B60` di atas `#FFFFFF`/`#F2F6F3`) tampak memenuhi, tapi
  verifikasi angka kontras manual belum dilakukan.

Item PENDING di atas adalah **gate rilis**, bukan kegagalan tersembunyi:
jangan tandai T42 "selesai untuk rilis" sampai checklist TalkBack manual
dijalankan di perangkat fisik.

## Checklist manual TalkBack (untuk dijalankan di perangkat fisik)

- [ ] Aktifkan TalkBack, navigasi `Tugas Hari Ini` → baca semua kandang.
- [ ] `Catatan Harian`: isi pakan/telur lewat keyboard, pastikan label terbaca.
- [ ] `Pusat Sinkronisasi`: aksi "Coba lagi" / "Batalkan draf" terjangkau & terbaca.
- [ ] `Temuan`: buka form, pastikan urutan baca field benar.
- [ ] Teks 200% di pengaturan perangkat: tidak ada teks terpotong.
- [ ] Tombol penting ≥ 48dp saat TalkBack aktif (target sentuh).

Redaksi: tidak ada secret/kredensial pada dokumen ini.
