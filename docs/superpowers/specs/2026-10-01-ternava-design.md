# TERNAVA — Spesifikasi MVP Ayam Petelur

Tanggal: 1 Oktober 2026 · Tier **T2** · Ceremony **L** · Rigor **spec-anchored**.
Status: **P4 disetujui melalui D-011; P5 plan disusun. Planning saja sesuai D-012; handoff execution belum dibekukan.**
Root project: `/mnt/data/porto/ternava`.

## Tujuan dan masalah

TERNAVA membantu operator mencatat kegiatan farm ayam petelur dan membantu pemilik meninjau data yang telah diterima. Fokus pertama adalah total pakan/telur per kelompok per hari, pekerjaan/SOP, temuan dengan tindak lanjut, dan stok yang dapat ditelusuri. Pengguna memilih Flutter, MVP mobile+backend, contoh fiktif karena belum ada farm, dan Docker lokal dahulu. Baseline visual 24 layar diterima untuk lanjut planning melalui D-009. AM-01 menambahkan kolom sandi sementara saat membuat akun pada member-form; perubahan ini diterima bersama spesifikasi melalui D-011. AM-02 menambahkan state edit dengan alasan perubahan kelompok dan field referensi awal terkunci pada contoh kelompok yang sudah tercatat.

Riset yang mendasari arah ini: [Kementan, 7 Agustus 2026](https://bpmsph.ditjenpkh.pertanian.go.id/berita/kementan-bekali-peternak-probolinggo-formulasi-pakan-sendiri-biaya-produksi-turun-untung-naik) membahas besarnya beban pakan pada peternak contoh Probolinggo; [riset SIMAPI UGM 2025](https://etd.repository.ugm.ac.id/penelitian/detail/263795) memberi konteks pencatatan/literasi digital pada peternakan sapi, bukan bukti langsung farm ayam. Masalah pencatatan harian, akses jaringan, dan serah data antaroperator masih hipotesis yang memerlukan validasi calon pilot. Tidak ada klaim bahwa TERNAVA telah menghemat biaya atau meningkatkan produksi.

| Goal | Bukti penerimaan |
|---|---|
| G1 Operator mempertahankan catatan meski jaringan terputus dalam lease | AC-10/12/13/19/23/24/33–35 |
| G2 Pengelola menelusuri stok/total/revisi tanpa penghitungan ganda | AC-13/15/16/26–32 |
| G3 Pekerjaan/temuan punya petugas dan status tindak lanjut | AC-11/12/18–20/22/38 |
| G4 Pemilik membaca kelengkapan accepted data menurut periode | AC-03/09/14/21/32 |
| G5 Data operasional terlindungi dan dapat dipulihkan untuk pilot | AC-08/24/35–37/40–47 |

## Scope dan aturan normatif

Android, bahasa Indonesia, tema terang, satu farm contoh (Asia/Jakarta/IDR), sampai20 kandang/10 akun/20 perangkat sebagai kapasitas template. Owner/admin/operator, satu gudang pusat, satu cohort per kandang per tanggal. Tanggal/rentang/kuantitas mengikuti `api-sync.md`; angka ini ruling desain untuk review, bukan fakta farm. Kondisi medis diinput pengamatan manual, tidak otomatis didiagnosis. Field jumlah wajib untuk kirim, nol eksplisit, draft boleh belum lengkap; satu harian adalah total, bukan event per shift.

Termasuk: akses/setup, kandang/cohort, role/assignment, total harian+revisi, stok/receipt/adjustment, tugas/SOP+hasil, temuan/action, foto privat, inbox/push, ringkasan/reportCSV, offlinequeue dan akun. Tidak termasuk: dashboardweb, onboardingcarousel, signup publik, individu tiap ayam, transfer gudang, IoT/AI, diagnosis/dosis, akuntansi/laba, PDF, chat, pembayaran, iOS/PlayStore release. Splash hanya transisi awal, bukan scope halaman marketing.

Kebijakan sesi/role/revisi/retensi/reliability di `api-sync.md` dan `operations-security.md` merupakan bagian spesifikasi yang diterima melalui D-011. Deployment nyata menunggu gate AC-47; development lokal boleh memakai data rekaan. Tenggat/anggaran proyek tidak ditebak. Provider berbayar dan kontak petugas nyata ditetapkan sebelum deployment, sesuai D-010.

## Desain dan interface

`DESIGN.md` normatif untuk tokens/hierarchy/spacing/behavior. Flutter merealisasikannya melalui widgets native; HTML tetap bukti visual, bukan code yang ditransplantasi literal. Fira Sans 400/600, primary #195647, body 16, target 48 dp, light background #F2F6F3; warna status disertai teks/icon. Baris kandang menampilkan status bertanggal. Angka contoh tidak diprefill pada form operasional baru. Motion 140 ms menghormati preferensi pengurangan motion. Kontras body 4.5:1, teks 200%/TalkBack diuji di Android. Preview controls AC-900 tidak masuk aplikasi.

Sumber kontrak: `contracts/openapi.json` (59 operations), `schema.json` (26 logical tables), `examples.json`; layer/modules di `architecture.md`, protocol/invariants di `api-sync.md`, operations di `operations-security.md`. Enforce melalui Dart DTO/fixtures+Laravel response contract tests dan PostgreSQL constraints/fault tests saat execution. Diagram di `docs/diagrams/` dihasilkan dari sumber JSON dan diperiksa drift. Semua keputusan perubahan harus menyebut AC/layar/kontrak terkait.

| Modul | Kriteria pokok |
|---|---|
| farm-access | AC-01/02/07/08/23/24/27/33–36/41/46 |
| flocks | AC-03–06/31 |
| feed-ledger | AC-15–17/30 |
| daily-operations | AC-10–14/26/28/29/32/37 |
| incidents | AC-18–20 |
| insights | AC-09/21/22/38 |
| Lintas modul | AC-25/39/40/42–45/47 |

## Acceptance criteria EARS

ID AC-01–25 tetap dari inventory; AC-26–47 merinci integritas, keamanan dan readiness. Verify berikut adalah metode pembuktian pada implementasi, bukan hasil test yang telah dijalankan.

### AC-01 · farm-access

WHEN login online berhasil, THE aplikasi SHALL membuka workspace role setelah referensi awal tersedia.

Verify: API + Flutter integration: login owner/operator, sandi salah, login pertama offline; periksa tujuan layar dan pesan pemulihan.

### AC-02 · farm-access

WHEN pengelola menyimpan farm valid, THE aplikasi SHALL menampilkan nama dan zona waktu yang diterima server.

Verify: API + widget: nama kosong, zona IANA tidak valid, role tanpa izin; perubahan zona setelah operasi pertama ditolak.

### AC-03 · flocks

WHILE operator membuka daftar kandang, THE aplikasi SHALL menampilkan hanya kandang dalam assignment aktif dengan status pencatatan bertanggal.

Verify: API + widget: operator ditugaskan ke dua kandang; kandang lainnya tidak terlihat, status bertanggal, empty/error/stale dapat dipulihkan.

### AC-04 · flocks

WHEN pengelola menyimpan kandang berkode unik, THE sistem SHALL menyediakan kandang itu sebagai referensi tanpa menimpa kode yang sudah dipakai.

Verify: API: create, replay, kode duplikat tanpa membedakan huruf besar/kecil; widget mempertahankan form invalid/offline.

### AC-05 · flocks

WHEN pengguna membuka kelompok kandang yang berizin, THE aplikasi SHALL memisahkan kelompok aktif dan selesai beserta rentang penempatannya.

Verify: API + widget: filter aktif/selesai, rentang penempatan; catatan kelompok lama tidak bercampur dengan kelompok baru.

### AC-06 · flocks

IF penempatan kelompok overlap atau populasi awal invalid, THEN THE sistem SHALL menolak perubahan dan mempertahankan isian lokal.

Verify: PostgreSQL/API concurrent: tanggal overlap, dua kelompok aktif, populasi nol/negatif, perubahan populasi awal sesudah transaksi pertama.

### AC-07 · farm-access

WHILE pengelola yang berizin membuka daftar pengguna, THE aplikasi SHALL menampilkan role dan penugasan akun farm tersebut.

Verify: API + widget: matriks owner/admin/operator, pengguna farm lain tidak terlihat; pagination/empty/error.

### AC-08 · farm-access

IF actor tidak memiliki izin mengubah role atau target owner pertama, THEN THE sistem SHALL menolak perubahan akses.

Verify: API: admin mengelola operator, admin mengubah admin/owner ditolak, owner membuat admin, pencabutan assignment.

### AC-09 · insights

WHEN ringkasan dimuat, THE aplikasi SHALL membedakan missing record, accepted record dan snapshot stale serta menyediakan link perhatian ke objek yang berizin.

Verify: API + widget: data sebagian/semua kosong dibanding accepted zero, refresh 500 mempertahankan snapshot dan waktu, link perhatian tepat.

### AC-10 · daily-operations

WHILE operator memiliki sesi offline yang berlaku dan cache penugasan, THE aplikasi SHALL menyediakan catatan/tugas cache yang ditugaskan pada Hari ini.

Verify: Flutter integration: mode pesawat dengan cache tujuh hari, assignment, cache kosong dan lease kedaluwarsa memiliki pemulihan.

### AC-11 · daily-operations

WHEN pengelola menyimpan tugas berjadwal dengan petugas berizin, THE sistem SHALL menyediakan occurrence sesuai tanggal dan SOP yang dimasukkan.

Verify: API/scheduler: once/daily/weekly, occurrence unik, petugas tidak berizin, zona waktu; tidak ada jadwal/dosis medis yang dihasilkan otomatis.

### AC-12 · daily-operations

WHEN petugas menyimpan kendala atau hasil tugas, THE aplikasi SHALL menyimpan intent lokal sebelum menunjukkan status menunggu kirim.

Verify: Flutter fault integration: disk gagal, relaunch, note tetap open, completed baru accepted sesudah ACK; cancelled/stale run menjadi konflik.

### AC-13 · daily-operations

WHEN pengguna menyimpan catatan harian lengkap, THE aplikasi SHALL mempertahankan total, tanggal, kelompok dan status penerimaannya sampai hasil server diketahui.

Verify: Flutter + API: draft belum lengkap, nol eksplisit, offline/relaunch, disk gagal, pending, accepted read-only dan revisi oleh pengelola.

### AC-14 · daily-operations

WHEN pengguna memfilter riwayat menurut tanggal/kandang, THE aplikasi SHALL menunjukkan catatan dalam cakupan beserta status lokal atau accepted yang berbeda.

Verify: API + widget: filter tanggal/kandang, pending tidak dihitung accepted, empty/error/offline, detail mengikuti izin.

### AC-15 · feed-ledger

WHEN pengelola membuka stok/ledger, THE aplikasi SHALL menampilkan saldo accepted, asal transaksi dan waktu pembaruan.

Verify: API + widget: receipt/daily/reversal/adjustment; saldo sama dengan penjumlahan ledger, waktu snapshot terlihat, tidak ada input pemakaian kedua.

### AC-16 · feed-ledger

WHEN transaksi pakan valid diterima, THE sistem SHALL memperbarui saldo sekali sesuai arah transaksi dan menyimpan asal/alasan yang diwajibkan.

Verify: PostgreSQL/API: opening sekali, receipt dengan harga/pemasok, adjustment beralasan, retry; saldo negatif dan overflow ditolak.

### AC-17 · feed-ledger

WHEN pengelola mengubah jenis pakan atau batas minimum, THE sistem SHALL mempertahankan referensi ledger historis.

Verify: API + widget: create, update version, jenis nonaktif dan histori; event ambang stok tidak berulang setiap refresh.

### AC-18 · incidents

WHEN pengguna memfilter temuan berdasarkan status/kandang, THE aplikasi SHALL menampilkan temuan dalam cakupan dengan status penugasan yang terlihat.

Verify: API + widget: filter status/kandang, unassigned/empty/error/offline; akses farm lain ditolak.

### AC-19 · incidents

IF jaringan atau upload foto gagal, THEN THE aplikasi SHALL mempertahankan pengamatan teks dan menunjukkan status foto secara terpisah.

Verify: Flutter + API fault: teks offline tahan relaunch, ACK teks lalu upload 500, foto tertunda tetap ada; file rusak/terlalu besar ditolak.

### AC-20 · incidents

WHEN actor berizin menetapkan petugas atau mencatat tindakan, THE sistem SHALL memperbarui versi/status temuan dengan actor dan histori tindakan.

Verify: API + widget: dua perubahan atas versi sama, petugas yang ditugaskan, actor tanpa izin; closing tanpa notes dan perubahan closed ditolak.

### AC-21 · insights

WHEN pengelola meminta laporan periode valid, THE sistem SHALL menyertakan accepted data, kelengkapan, zona waktu dan as_of pada laporan/CSV.

Verify: PostgreSQL/API + Flutter: rentang 183 hari, missing null/accepted zero, batas tengah malam farm, CSV escaping/injection dan ekspor gagal.

### AC-22 · insights

WHEN pengguna membuka pemberitahuan, THE aplikasi SHALL memeriksa akses objek dan menyediakan jalan kembali apabila objek tak tersedia.

Verify: API + widget: inbox milik sendiri, link setelah akses dicabut atau objek tidak ada; inbox tetap tersedia tanpa izin push.

### AC-23 · farm-access

IF pengiriman belum mendapat ACK atau ditolak, THEN THE aplikasi SHALL menunjukkan status item dan tindakan pemulihan tanpa menghapus payload.

Verify: Flutter fault integration: timeout setelah commit, 429/401/403/409/422/500; retry mempertahankan key/payload, reauth mempertahankan antrean.

### AC-24 · farm-access

WHEN pengguna keluar akun atau mengganti akun, THE aplikasi SHALL mengunci data lokal identitas sebelumnya setelah konfirmasi bila ada antrean.

Verify: Android integration: akun A pending lalu logout confirm/cancel, akun B tidak membaca A, A login kembali; ganti sandi pertama dan izin push ditolak.

### AC-25 · all

WHEN pengguna menavigasi atau kembali dengan isian belum tersimpan, THE aplikasi SHALL menyediakan tujuan sesuai role dan konfirmasi untuk mempertahankan isian.

Verify: Flutter widget/integration: seluruh 24 screen ID, back/deep link, batal membuang isian, link inbox/sync; toolbar preview tidak muncul pada app.

### AC-26 · daily-operations

WHEN server menerima catatan harian, THE sistem SHALL mengcommit daily, versi, efek ledger/populasi, receipt dan event sebagai satu unit.

Verify: PostgreSQL fault injection: exception pada setiap titik transaksi menghasilkan nol efek parsial; respons hilang setelah commit direplay sekali.

### AC-27 · farm-access

WHEN request dengan key dan isi identik dikirim ulang oleh actor yang masih berizin, THE sistem SHALL mengembalikan ACK asli tanpa efek bisnis tambahan.

Verify: API concurrency: 20 request sama, reauth actor sama, efek record/ledger/event satu; key sama dengan isi berbeda menghasilkan 409.

### AC-28 · daily-operations

IF catatan farm/kelompok/tanggal sudah ada, THEN THE sistem SHALL menolak create lain tanpa menjumlahkan total harian.

Verify: API concurrency: dua operator dengan resource ID/key berbeda pada kelompok/tanggal sama; satu accepted, total tidak dijumlahkan.

### AC-29 · daily-operations

IF base_version revisi berbeda dari versi terkini, THEN THE sistem SHALL menolak revisi tanpa mengubah catatan atau ledger.

Verify: API race: dua admin mengirim base_version=1, hanya satu versi 2; lainnya 409, snapshot/reason/actor lama tetap tersedia.

### AC-30 · feed-ledger

IF saldo setelah mutasi akan negatif atau overflow, THEN THE sistem SHALL menolak seluruh intent bisnis.

Verify: PostgreSQL concurrent: konsumsi 270+270 kg atas saldo 300 kg, revisi beda jenis pakan; seluruh tabel diperiksa setelah penolakan.

### AC-31 · flocks

IF perubahan catatan membuat populasi pada suatu tanggal negatif, THEN THE sistem SHALL menolak perubahan itu beserta efek harian lainnya.

Verify: API: populasi awal 100, catatan mundur masuk/keluar/mortalitas dan revisi; semua prefix tanggal nonnegatif, null tetap belum diperiksa.

### AC-32 · daily-operations

WHILE field jumlah belum diisi atau belum diperiksa, THE aplikasi SHALL menampilkan keadaan belum dicatat alih-alih nilai nol atau status sehat.

Verify: Widget/schema/API: pakan/telur kosong tidak masuk antrean, draft boleh kosong, mortality null, condition not_checked, nol eksplisit accepted.

### AC-33 · farm-access

WHEN delta sync diterapkan, THE aplikasi SHALL menyimpan perubahan cache dan cursor bersama.

Verify: Drift fault integration: crash saat menerapkan changes/cursor, relaunch dan replay; cache/cursor konsisten, akses yang dicabut ditangani.

### AC-34 · farm-access

IF cursor kedaluwarsa atau scope berubah, THEN THE aplikasi SHALL mengganti snapshot accepted melalui bootstrap tanpa menghapus draft/outbox.

Verify: API + mobile: mutasi selama bootstrap bertahap, transaksi commit berbeda urutan, snapshot/cursor kedaluwarsa, assignment berubah; draft/outbox tetap ada.

### AC-35 · farm-access

IF offline lease habis atau validasi online menolak sesi, THEN THE aplikasi SHALL menghentikan akses/penulisan farm dan mengirim pengguna ke autentikasi ulang.

Verify: Android clock/network: expiry 24 jam, restart, jam mundur, 401/403; payload pending bertahan dan cache terkunci sampai reauth.

### AC-36 · farm-access

WHEN pengguna meminta resource, replay, export atau file, THE sistem SHALL memeriksa izin farm/role/kandang terkini.

Verify: API negative matrix untuk seluruh 59 operasi: role yang tepat, forged resource/parent/cursor, replay dan download; tidak ada data silang farm/akun.

### AC-37 · daily-operations

IF foto melebihi batas, isi bukan JPEG/PNG atau parent tidak berizin, THEN THE sistem SHALL menolak upload tanpa membuat lampiran dapat diakses.

Verify: API: MIME palsu, ukuran 2 MiB+1 byte, foto keempat, hash berbeda, EXIF dihapus, download tanpa izin dan pembersihan orphan.

### AC-38 · insights

IF push gagal atau izin perangkat ditolak, THEN THE sistem SHALL tetap menyediakan inbox event yang diterima tepat sekali.

Verify: Worker/API: event diproses ulang, FCM 500/token mati dan izin ditolak; inbox unik per event/user, izin objek diperiksa saat dibuka.

### AC-39 · all

WHILE layar sedang empty, loading, refresh-error atau restricted, THE aplikasi SHALL menampilkan state inventory dengan jalan pemulihan yang relevan.

Verify: Widget fixtures seluruh 24 layar/132 state: empty/loading/error/restricted, retry relevan, isian dipertahankan, tanpa nol atau stacktrace palsu.

### AC-40 · all

WHILE pengguna memakai TalkBack atau teks 200%, THE aplikasi SHALL menjaga label, urutan baca, aksi penting dan target sentuh minimal48dp dapat digunakan.

Verify: Android manual + widget: lebar 320/414 dp, TalkBack pada flow kritis, teks 200%, reduced motion, target 48 dp dan kontras body minimal 4,5:1.

### AC-41 · farm-access

IF request melampaui rate/size/range yang dikontrak, THEN THE sistem SHALL menolak dengan error yang dapat dipulihkan tanpa efek bisnis.

Verify: API abuse: login 5/menit per username+IP, auth 120/menit, upload 10/menit, export 3/menit, JSON 64 KiB, limit 100, report 184 hari, Retry-After.

### AC-42 · all

WHEN versi pilot dirilis, THE sistem SHALL menyediakan artefak bertanda tangan, versi dependency yang terkunci dan hasil pemeriksaan keamanan/kontrak.

Verify: Release gate: verifikasi signed APK/image digest/SBOM/lockfiles, scanner staged/history, dependency audit, full validator dan DTO/API fixtures nyata.

### AC-43 · all

WHEN backup pilot direstore, THE sistem SHALL memulihkan data/izin sesuai snapshot dengan ledger konsisten dalam RTO 4jam dan kehilangan maksimal RPO 24jam.

Verify: Restore drill ke environment terpisah: jumlah record/FK/ledger/file ACL/login/deletion journal; ukur waktu restore dan umur backup terhadap RTO/RPO.

### AC-44 · all

WHILE API melayani benchmark yang ditetapkan, THE sistem SHALL memenuhi target latency/error tanpa duplicate business effect.

Verify: Load: 2 vCPU/4 GiB, 100 ribu daily records, 20 client selama 15 menit; p95 read<=500 ms/write<=1 detik, unexpected error<1%, efek duplikat=0.

### AC-45 · all

WHEN terjadi gangguan layanan, THE sistem SHALL menyediakan metrik/status yang membedakan kegagalan API, queue, backup dan push.

Verify: Ops: hentikan worker/API/FCM, periksa probe/heartbeat/threshold/log teredaksi/queue durable; ukur SLO bulanan 99,5% sesudah pilot berjalan.

### AC-46 · farm-access

WHEN retensi atau penghapusan berizin dijalankan, THE sistem SHALL menjaga integritas ledger dan dedup intent yang masih dapat direplay.

Verify: Retention: jendela 730/180/90/30/14 hari, replay key lama terhadap tombstone, orphan file, backup 30 hari dan deletion journal.

### AC-47 · all

WHEN peternakan nyata akan mulai pilot, THE project SHALL memiliki hasil validasi alur/perangkat, penanggung jawab, biaya/provider, restore dan penerimaan UAT yang tercatat.

Verify: Dokumen/UAT: farm nyata, perangkat dan alur tervalidasi, checks operations-security.md, penanggung jawab/provider/biaya/retensi, restore, sign-off owner.


## Pemeriksaan kualitas dan status gate

Semua47 AC memakai EARS dan Verify, semua 5 goal/6 modul/24 screen ditautkan. Tidak ada kriteria yang meminta Redis/teknologi tertentu sebagai hasil user; pilihan runtime berada pada desain. Empty/error/permission dan data kosong dicakup oleh AC-01/03/08/09/23/36/39. Bentuk API dan contoh divalidasi secara struktural oleh tooling lokal; pemeriksaan penuh terhadap server/native hanya dapat dilakukan sesudah implementasi.

Scope, aturan, kontrak, target uji dan AM-01/02 diterima melalui D-011. Rencana implementasi ditulis di `../plans/2026-10-01-ternava-mvp.md`; `HANDOFF.candidate.md` mencatat readiness dan batas planning D-012. Feature code belum ditulis. Persetujuan spesifikasi tidak menjadi izin mulai eksekusi. Paket belum disebut factory-ready: SDK Flutter, scaffold apps, lockfiles, remote CI dan konfigurasi Firebase masih belum tersedia. Daftar konkret berada pada `factory-readiness.md`.
