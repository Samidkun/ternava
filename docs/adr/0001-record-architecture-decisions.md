# ADR-0001 — Kontrak sebelum Flutter/backend

Status: proposed untuk review P4, 1 Oktober 2026.

Pengguna memilih Flutter, MVP mobile+backend, ayam petelur dan Docker lokal. Data farm belum tersedia. UI harus mempertahankan intent offline sementara backend memegang izin/transaksi/accepted data.

Keputusan: MVVM Flutter+Drift, Laravel 13/PHP 8.4/PostgreSQL 18 satu backend dan worker/scheduler. Kontrak API/schema dahulu, receipt idempotensi dan ledger atomic, inbox durable dengan FCM optional. Detail normatif di architecture.md dan api-sync.md. Exact patch/plugin/digest dipin sebelum fitur, deployment tidak dipilih sekarang.

Konsekuensi: butuh uji relaunch/concurrency/account isolation; pilihan total harian/gudang pusat/cohort harus divalidasi pada farm sebelum pilot. Redis/microservices/full finance menambah beban tanpa kebutuhan awal yang terbukti.
