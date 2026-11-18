# bot_mock — Simulasi ESP32-01 Hidup (Bun + TypeScript)

Simulasi pengganti firmware ESP32 saat perangkat asli belum ada / lagi mati.
Bikin aplikasi ANDROMEDA kelihatan **beneran hidup**: badge Online, gauge gerak,
grafik keisi, tombol valve ada feedback `pending → executed`.

> Folder ini **mandiri**. Semua docs bot ada di file ini aja —
> nggak nyentuh `docs/`, `README.md` root, atau `SETUP.md`.

## 1. Syarat

- [Bun](https://bun.sh) ≥ 1.0 (`bun --version`)
- File `.env` di **root projek** sudah diisi (sumber utama):

```bash
cp .env.example .env   # di root projek, lalu isi
```

Bot baca env dengan urutan: `export` manual → `tools/bot_mock/.env`
(opsional) → root `.env` → `mobile_app/.env`. Jadi paling gampang:
cukup isi root `.env`, nggak perlu bikin env di sini.

## 2. Cara jalan

```bash
cd tools/bot_mock
bun install          # nggak ada dependency, cuma generate lockfile

# Simulasi jalan terus (tick 30 detik, realistis)
bun src/bot_mock.ts --mode live

# Demo cepat (tick 10 detik, gauge kelihatan gerak)
bun src/bot_mock.ts --mode live --fast

# Sekali kirim lalu keluar (buat tes / cron)
bun src/bot_mock.ts --mode live --once

# Isi grafik 7 hari ke belakang (sekali jalan, biar chart 1H/1M penuh)
bun src/bot_mock.ts --mode backfill --days 7

# Cek tanpa nulis ke Supabase
bun src/bot_mock.ts --mode live --dry-run

# Hapus data simulasi 1 hari terakhir (HATI-HATI, butuh --yes)
bun src/bot_mock.ts --mode cleanup --days 1 --yes
```

Shortcut via `package.json`:

```bash
bun run live | bun run live:fast | bun run once | bun run backfill | bun run dry-run
```

## 3. Opsi lengkap

| Opsi | Default | Fungsi |
|---|---|---|
| `--mode live\|backfill\|cleanup` | `live` | Pilih kerjaan bot |
| `--days N` | `7` | Backfill/cleanup: rentang hari (1–30) |
| `--interval N` | `30` | Detik antar tick live (5–3600) |
| `--fast` | — | Shortcut `--interval 10` |
| `--only A,B` | semua 6 | Batasi petak, cth `--only petak-01,petak-02` |
| `--once` | — | Live sekali tick lalu keluar |
| `--dry-run` | — | Cetak payload, JANGAN tulis ke Supabase |
| `--no-faults` | — | Matikan injeksi SENSOR ERROR |
| `--yes` | — | Konfirmasi cleanup (wajib) |
| `--help` | — | Tampilkan bantuan |

## 4. Cara kerja (mirip `hardware/firmware/src/main.cpp`)

Tiap tick live:

1. `GET system_config` per petak → patuhi `mode`, `threshold_dry/wet`,
   `valve_duration`, `read_interval`.
2. `GET pending_commands?status=pending` per petak → kalau ada `VALVE_ON`
   buka valve, `VALVE_OFF` tutup valve → `PATCH ... status=executed`.
   `VALVE_ON duration 0` + mode `manual` = terbuka indefinite (kayak firmware).
3. Valve yang durasinya habis auto-close (max 120 detik, `VALVE_MAX_DURATION_MS`).
   Mode `auto` + tanah kering (`pct < threshold_dry`) → siram otomatis.
4. Random-walk kelembaban + pola siang kering / malam basah + boost saat valve ON,
   konversi `raw = 2700 − pct/100 × 1200`, clamp ADC `100..4000`.
5. `POST /sensor_readings` **batch 6 petak sekaligus** (kayak firmware).
6. `POST /rpc/heartbeat` tiap 60 detik → `devices.last_seen` fresh → badge **Online**.

## 5. Profil 6 petak (biar nggak kelihatan bot)

| Petak | Karakter |
|---|---|
| `petak-01` | Normal lembab ~55% |
| `petak-02` | Kering ~25%, sering trigger siram otomatis |
| `petak-03` | Basah ~80%, habis disiram |
| `petak-04` | Fluktuatif siang/malam (±12%) |
| `petak-05` | Standar ~45%, cocok buat demo tombol manual dari HP |
| `petak-06` | Normal ~60% + injeksi fault ~1.5% (uji UI SENSOR ERROR) |

Pakai `--no-faults` kalau mau demo bersih ke petani (tanpa badge error).

## 6. Bedanya sama firmware asli (sengaja)

- **Interval demo, bukan 30 menit.** DB `read_interval` default 1800 detik bikin
  demo kelihatan mati, jadi bot pakai tick 30 detik (`--fast` 10 detik).
  `read_interval` DB tetap dibaca buat jendela expiry command (`2× interval`).
- **1 proses = 6 petak.** Sama kayak `esp32-01` asli (1 ESP32 kelola 6 petak).
- **Backfill nyisipin 1 titik "sekarang"** biar badge langsung Online setelah isi histori.
- **Jangan jalan bareng firmware asli.** Datanya tabrakan (dua penulis).

## 7. Checklist validasi di app

1. Home: kartu `esp32-01` ijo `6/6 online`, angka tiap petak beda-beda.
2. Dashboard: gauge gerak tiap tick, grafik historis keisi setelah backfill.
3. Pencet **Buka valve** di HP → dalam 1 tick jadi `pending → executed`, valve ON, lalu OFF sendiri.
4. Matikan bot >60 menit → app jadi Offline + banner "Data tersimpan" (cache jalan).
5. Tanpa `--no-faults`, sesekali muncul SENSOR ERROR tapi grafik nggak spike aneh.

## 8. Troubleshooting

| Gejala | Penyebab umum | Solusi |
|---|---|---|
| `SUPABASE_URL / ANON_KEY kosong` | root `.env` belum diisi | Isi root `.env`, jangan cuma `.env.example` |
| `POST ... → GAGAL` / 401 | Key salah / RLS belum sesuai `schema.sql` | Cek key di dashboard Supabase → Project Settings → API; jalankan `database/schema.sql` |
| `GET ... 404` | Tabel belum ada | Jalankan `database/schema.sql` + migrasinya |
| Semua Offline padahal bot jalan | `last_seen` basi / jam beda zona | Pastikan bot kirim heartbeat (log `heartbeat ... OK`), cek `devices.last_seen` di Table Editor |
| Grafik kosong | Belum ada histori | Jalanin `--mode backfill --days 7` sekali |
| Command stuck `pending` | Bot mati / `--dry-run` | Nyalakan live tanpa dry-run; bot eksekusi tiap tick |

## 9. Keamanan

- Key yang dipakai = **anon public key** (sama kayak app), RLS `schema.sql` ngasih akses ALL ke anon — wajar untuk projek ini.
- `--dry-run` dulu sebelum live kalau ragu sama rumus/kuota.
- `--mode cleanup` menghapus data beneran — selalu cek `--days` + `--only` dulu pakai `--dry-run`.
- Jangan commit file `.env` (sudah di-ignore via `*.env` di root `.gitignore`).
