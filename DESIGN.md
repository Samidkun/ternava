---
version: alpha
name: TERNAVA
description: Pencatatan kandang yang jelas, tenang, dan mudah dipakai di lapangan.
colors:
  primary: "#195647"
  primary-pressed: "#123F35"
  secondary: "#52635E"
  tertiary: "#855419"
  neutral: "#F2F6F3"
  surface: "#FFFFFF"
  text: "#1E3029"
  muted: "#56645D"
  border: "#C6D2CA"
  field-border: "#7A8F81"
  success: "#226249"
  success-surface: "#EAF4ED"
  warning: "#805213"
  warning-surface: "#FFF3DC"
  danger: "#A53332"
  danger-surface: "#FCEDEC"
  info: "#245776"
  info-surface: "#EBF3F8"
typography:
  title:
    fontFamily: Fira Sans
    fontSize: 26px
    fontWeight: 600
    lineHeight: 1.2
  section:
    fontFamily: Fira Sans
    fontSize: 19px
    fontWeight: 600
    lineHeight: 1.3
  body-md:
    fontFamily: Fira Sans
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: Fira Sans
    fontSize: 14px
    fontWeight: 500
    lineHeight: 1.4
  caption:
    fontFamily: Fira Sans
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.4
  value:
    fontFamily: Fira Sans
    fontSize: 32px
    fontWeight: 600
    lineHeight: 1.15
    fontFeature: "tnum"
rounded:
  input: 8px
  button: 10px
  surface: 16px
  sheet: 24px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  section: 32px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.surface}"
    rounded: "{rounded.button}"
    height: 52px
    padding: 16px
  button-primary-pressed:
    backgroundColor: "{colors.primary-pressed}"
    textColor: "{colors.surface}"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    rounded: "{rounded.button}"
    height: 48px
    padding: 12px
  field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.input}"
    height: 52px
    padding: 12px
  status-warning:
    backgroundColor: "{colors.warning-surface}"
    textColor: "{colors.warning}"
    padding: 12px
  status-danger:
    backgroundColor: "{colors.danger-surface}"
    textColor: "{colors.danger}"
    padding: 12px
  status-success:
    backgroundColor: "{colors.success-surface}"
    textColor: "{colors.success}"
    padding: 12px
  status-info:
    backgroundColor: "{colors.info-surface}"
    textColor: "{colors.info}"
    padding: 12px
---

## Overview

Foundation baru (establish), belum ada sistem visual sebelumnya. Subjek: operasional peternakan ayam petelur. Audiens: operator kandang, pemilik, admin. Pekerjaan utama: menyimpan catatan lapangan lalu menggunakan catatan yang diterima untuk tindak lanjut.

Voice: lugas, tenang, konkret. Gunakan “kandang”, “pakan dipakai”, “telur terkumpul”, “belum dicatat”, “tersimpan di perangkat”, dan “diterima sistem”. Hindari istilah API, ledger, payload, idempotensi, dan queue pada teks aplikasi.

Signature bet: **baris kandang dengan status pencatatan bertanggal**. Kandang menjadi unit orientasi: nama → kelompok ayam → status pakan/telur/temuan. Baris yang belum dicatat mengundang tindakan. Struktur ini menghubungkan pekerjaan operator dengan perhatian pemilik, lebih penting daripada deretan kartu KPI.

Knobs: DESIGN_VARIANCE 4; VISUAL_DENSITY 6; MOTION_INTENSITY 2. Familiar Material navigation, form, snackbar, dialog. Preview HTML memakai padanan CSS dari token ini; produksi Flutter memakai ThemeData dan widget yang mengikuti hierarki/perilaku yang disetujui.

## Colors

Hijau tua untuk aksi utama, warna netral terang untuk latar dan permukaan. Warna amber hanya untuk perhatian/tertunda, merah untuk gagal/perlu perbaikan, biru untuk informasi. Status selalu memiliki teks dan bentuk/ikon; warna tidak menjadi satu-satunya pembeda.

Warna bukan klaim keamanan medis. “Belum diperiksa” memakai label netral; tidak menjadi “sehat”. Angka yang belum tersedia ditulis “Belum dicatat”. Semua pasangan teks/latar diuji minimal 4,5:1. Outline/focus menggunakan primary dan jarak yang terlihat.

## Typography

Fira Sans dipilih untuk teks kerja dengan bentuk humanis, hierarki yang tegas, dan angka yang mudah disejajarkan. Satu keluarga dipakai untuk judul/body/angka; angka memakai tabular figures. Font preview disematkan dari font lokal agar tidak memerlukan jaringan; font produksi dibundel dengan lisensi pada fase implementasi.

Body 16px, label 14px, caption 13px. Angka besar hanya pada ringkasan yang membantu keputusan. Nama peternakan/kandang panjang boleh membungkus. Produksi mengikuti text scaling Android sampai 200%; mockup web memeriksa zoom/text growth sebagai pendekatan awal, bukan bukti native.

## Layout

Main left aligned; area form satu kolom. Batas preview mobile 430px, konten adaptif hingga 320px. Tidak memakai tabel horizontal lebar di telepon: ledger berupa baris dengan label dan angka sejajar. Detail tampil setelah pemilihan baris.

Ritme 8–12px dalam grup, 24–32px antarbagian. Konten scroll satu area; CTA di akhir form, navbar tetap menjadi bagian alur dokumen agar tidak menutupi keyboard/konten. Flutter memakai safe area dan keyboard insets. Tap target minimal 48dp pada produksi dan 48px pada preview.

Orientasi → status data → pekerjaan utama → aksi utama → detail pendukung. Operator membuka Hari ini; pemilik membuka Ringkasan. Tombol primer “Simpan catatan”, “Selesaikan tugas”, atau “Catat tindakan” sesuai layar, bukan “Submit”.

## Elevation & Depth

Permukaan normal menggunakan batas halus atau perbedaan latar, tanpa shadow bertingkat. Dialog/preview device memakai satu shadow rendah: 0 8px 24px rgba(30,48,41,.10). Tidak ada nested cards, glassmorphism, glow, gradient dekoratif, atau animasi masuk berulang.

## Shapes

Input radius 8px, tombol 10px, ringkasan 16px, sheet/dialog 24px. Badge teks sederhana. Ikon garis satu keluarga dengan stroke 1,8px, ukuran 20–24px; nama aksesibel pada kontrol. Wordmark TERNAVA merupakan teks, bukan logo final atau ikon launcher yang telah disetujui.

## Components

1. **Baris kandang:** nama/kelompok/status bertanggal dan satu tujuan detail; primary action muncul pada kandang belum tercatat.
2. **Field jumlah dengan satuan:** label permanen, satuan kg/butir/ekor, keyboard angka, pesan validasi di dekat field. Nilai kosong tidak berubah menjadi nol.
3. **Status penyimpanan:** “Draft di perangkat”, “Menunggu dikirim”, “Diterima sistem”, “Perlu ditinjau”. Tidak menyebut berhasil server sebelum diakui.
4. **Baris tindak lanjut:** temuan, kandang, petugas atau “Belum ditugaskan”, tindakan berikutnya/status; menuju detail.

Loading berupa placeholder yang tidak menyembunyikan jalan kembali. Refresh gagal boleh mempertahankan snapshot bertimestamp. Kesalahan simpan mempertahankan isian. Empty state mengarahkan ke aksi relevan sesuai role. Dialog keluar menjelaskan antrean, tombol “Tetap di aplikasi” dan “Keluar akun”.

Motion untuk feedback/perubahan state: 140ms ease-out, exit 100ms, tidak scale dari 0, tidak transition all. Reduced motion meniadakan transisi nonesensial; hasil/status tetap terlihat.

## Do's and Don'ts

- Satu pekerjaan utama per layar; tampilkan label lengkap pada angka penting.
- Bedakan contoh preview dari data peternakan; jangan menulis keberhasilan yang belum diuji.
- Tanggal contoh 1 Oktober 2026 mengikuti zona waktu peternakan contoh.
- CTA/state/control ditelusuri ke AC pada screen inventory.
- Kontrol preview tidak menjadi UI produksi. Tidak ada lorem ipsum atau widget yang tak punya tujuan.
- Tidak menaruh data sistem/rahasia pada UI pengguna. Tidak memakai emoji sebagai ikon atau warna sebagai satu-satunya makna.
- Tema gelap, ilustrasi, branding launcher, dan mikrointeraksi dekoratif ditunda. Fokus pada keterbacaan, satuan, status data, dan pemulihan.

## Sumber dan batas verifikasi

[Dokumentasi aksesibilitas Flutter](https://docs.flutter.dev/ui/accessibility) memberi dasar checklist native; pemeriksaan preview browser tidak menggantikan TalkBack/text scaling pada perangkat Android. Target contrast mengikuti [W3C SC 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html). Font mengacu pada [Fira](https://github.com/mozilla/Fira); salinan OFL disertakan pada preview dan font tidak dimodifikasi desainnya.
