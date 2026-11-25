# bot_mock — Virtual ESP32-01 ANDROMEDA (Bun + TypeScript)

Simulator perangkat ESP32-01 non-blocking saat hardware asli belum dipasang / sedang mati.
Berperilaku **selayaknya `hardware/firmware/src/main.cpp` asli**:
- **Interval record sensor tiap 30 menit (1800 detik)** — otomatis mengikuti `system_config.read_interval` dari Supabase (default 30 menit).
- **Respon perintah & feedback instan (tiap 5 detik)** — tombol **BUKA / TUTUP** valve di app langsung dieksekusi (`pending → executed` + `executed_at`), lalu bot langsung melakukan **immediate push `sensor_readings`** (`valve_status: "ON"` / `"OFF"`), dan ketika durasi valve habis, auto-close langsung mengirim **immediate push** pasca-siram tanpa menunggu siklus 30 menit.
- **Pola kelembaban & aki realistis non-template** — model neraca air zona akar (*root-zone water balance*) yang digerakkan jam lokal, suhu udara, kelembaban udara (VPD), radiasi surya, angin, hujan, jenis tanah, mulsa, naungan, dan infiltrasi air bertahap. Mendukung cuaca riil gratis dari **Open-Meteo** (live & histori `past_days`) dengan fallback otomatis ke generator cuaca tropis prosedural saat offline.

> Folder ini **mandiri**. Semua docs bot ada di file ini aja —
> nggak nyentuh `docs/`, `README.md` root, atau `SETUP.md`.

## 1. Syarat

- [Bun](https://bun.sh) ≥ 1.0 (`bun --version`)
- File `.env` di **root projek** sudah diisi (`SUPABASE_URL` dan `SUPABASE_ANON_KEY`):

```bash
cp .env.example .env   # di root projek, lalu isi
```

Urutan baca env: `export` manual → `tools/bot_mock/.env` (opsional) → root `.env` → `mobile_app/.env`.
Opsional: tambahkan `BOT_LAT` dan `BOT_LON` di `.env` jika ingin menyelaraskan cuaca Open-Meteo dengan koordinat lahan spesifik.

## 2. Cara jalan

```bash
cd tools/bot_mock
bun install

# Mode produksi (record sensor tiap 30 menit, poll perintah tiap 5 detik, heartbeat 60 detik)
bun run live

# Demo cepat (record 30 detik, poll perintah 3 detik)
bun run live:fast

# Isi histori 7 hari ke belakang (tiap 30 menit, pola cuaca & irigasi realistis)
bun run backfill

# Sekali siklus lalu keluar (buat tes / cron)
bun run once

# Cek output tanpa nulis ke Supabase
bun run dry-run
bun run backfill:dry

# Jalankan typecheck & unit tests
bun run check
bun test

# Hapus data simulasi N hari terakhir (HATI-HATI, butuh --yes)
bun src/bot_mock.ts --mode cleanup --days 1 --yes
```

## 3. Opsi lengkap

| Opsi | Default | Fungsi |
|---|---|---|
| `--mode live\|backfill\|cleanup` | `live` | Pilih mode bot |
| `--interval N` | `1800` (30 mnt) | Kunci interval record sensor (10–7200 dtk). Jika tidak diisi, ikut `system_config.read_interval` DB (default 1800s) |
| `--cmd-poll N` | `5` | Detik antar cek `pending_commands` (2–60 dtk, independen dari siklus 30 mnt) |
| `--fast` | — | Shortcut demo: `--interval 30 --cmd-poll 3` |
| `--weather MODE` | `auto` | `auto` (Open-Meteo + fallback prosedural), `open-meteo`, atau `synthetic` (offline penuh) |
| `--lat N --lon N` | `-7.7956, 110.3695` | Koordinat cuaca Open-Meteo (override `BOT_LAT`/`BOT_LON`) |
| `--days N` | `7` | Rentang hari untuk `backfill` / `cleanup` (1–30) |
| `--only A,B` | semua 6 | Batasi petak, cth `--only petak-01,petak-02` |
| `--seed N` | acak | Seed PRNG (untuk pengujian deterministik) |
| `--no-hydrate` | hidrasi aktif | Jangan baca kelembaban terakhir dari Supabase saat boot |
| `--faults` | mati | Aktifkan injeksi `SENSOR ERROR` langka di `petak-06` (uji UI error) |
| `--no-faults` | mati | Pastikan injeksi fault mati (kompatibilitas mundur) |
| `--once` | — | Jalankan 1 siklus boot + push lalu keluar |
| `--dry-run` | — | Cetak payload tanpa menulis ke Supabase |
| `--yes` | — | Konfirmasi wajib untuk mode `cleanup` |
| `--help` | — | Tampilkan bantuan |

## 4. Arsitektur Virtual ESP32-01 (Multi-Timer Non-Blocking)

Mirip `hardware/firmware/src/main.cpp`, bot menjalankan 5 jadwal independen:

1. **Saat Boot:**
   - Muat data cuaca (Open-Meteo atau fallback prosedural), tarik `system_config` 6 petak, hidrasi kelembaban awal dari reading terakhir Supabase (supaya grafik nyambung mulus tanpa lompatan), kirim heartbeat awal + 1 siklus record sensor pertama.
2. **Tiap 1 detik (Valve & Fisika):**
   - Integrasikan penguapan/hujan/tetesan drip aktual per detik.
   - Begitu durasi valve habis (`auto-close`) → langsung kirim **immediate push `sensor_readings`** (`valve_status: "OFF"`, kelembaban naik, tegangan aki pulih) dengan debounce 2 detik.
3. **Tiap 5 detik (`--cmd-poll`, Command & Feedback):**
   - Batch `GET /pending_commands?status=eq.pending`.
   - Command basi (`umur > 2 × read_interval`) otomatis ditandai `expired`.
   - Sebelum eksekusi, segarkan `system_config` petak tersebut agar mode `auto`/`manual` selalu akurat.
   - Eksekusi `VALVE_ON` (termasuk `duration 0` + mode `manual` = indefinite) atau `VALVE_OFF` → `PATCH status=executed, executed_at=NOW` → **immediate push `sensor_readings`** agar aplikasi langsung memperbarui badge & status valve secara real-time.
4. **Tiap 60 detik (Heartbeat):**
   - `POST /rpc/heartbeat { _esp32_id: "esp32-01" }` → `devices.last_seen` selalu segar → status app tetap **Online (6/6)** di sela siklus sensor 30 menit.
5. **Tiap 120 detik (Sync Config) & Tiap 30 menit (Record Sensor):**
   - Menangkap perubahan slider `mode`, `threshold_dry/wet`, `valve_duration`, dan `read_interval` dari app.
   - Pada siklus 30 menit: evaluasi mode `auto` (`rootPct < threshold_dry` → buka valve sesuai `valve_duration`) lalu `POST /sensor_readings` batch 6 petak.
6. **Graceful Shutdown (`Ctrl+C`):**
   - Menutup valve yang masih terbuka (fail-safe solenoid NC) dan mengirim 1 snapshot `OFF` sebelum keluar.

## 5. Model Pola Realistis (Non-Template)

Alih-alih memakai fungsi kosinus statis yang naik-turun sama tiap hari, setiap petak menggunakan **neraca air zona akar** (*root-zone water balance*):
- **Evapotranspirasi berbasis VPD** (dari suhu udara, RH, radiasi surya, angin, koefisien tanaman `Kc`, mulsa, dan naungan pagi/sore): cepat mengering di siang terik, sangat landai di malam hari (hanya embun mikro tipis menjelang fajar saat RH > 86%, tidak melompat naik artifisial).
- **Infiltrasi dua lapis & drainase gravitasi:** air dari drip valve atau hujan meresap bertahap (`wettingBuffer → rootPct`), dan kelebihan air di atas kapasitas lapang (`fieldCapacity`) terdrainase eksponensial.
- **Sensor Kapasitif v1.2:** menyertakan drift termal dielektrik per sensor, bias kalibrasi kecil, dan noise Gaussian ADC 12-bit (`1500` basah – `2700` kering, valid `100..4000`).
- **Aki 12V + Solar Panel 300Wp:** melacak State-of-Charge (SoC) sesuai radiasi surya aktual (hari mendung/hujan tegangan cas lebih rendah) + **voltage sag `-0.18V` per solenoid valve yang `ON`**.

| Petak | Tanaman & Karakter Tanah |
|---|---|
| `petak-01` | Cabai Merah — Lempung berpasir + mulsa plastik (evaporasi tertahan mulsa) |
| `petak-02` | Tomat — Tanah berpasir / bedengan tinggi (paling cepat kering → alami memicu auto-siram) |
| `petak-03` | Sawi / Sayur Daun — Lempung subur + naungan pagi (retensi tinggi, tahan lembab lebih lama) |
| `petak-04` | Terong — Liat berpasir tepi lahan (paparan angin & kontras suhu siang-malam paling terasa) |
| `petak-05` | Bawang Merah — Lempung gembur datar (dinamika seimbang, ideal uji kontrol manual) |
| `petak-06` | Kacang Panjang — Lempung liat ujung saluran (debit drip ~85%, kandidat opsional `--faults`) |

## 6. Struktur Modul

```text
tools/bot_mock/
├── src/
│   ├── bot_mock.ts      # CLI entrypoint & .env loader
│   ├── esp32_sim.ts     # Runtime virtual ESP32-01 (live, backfill, cleanup)
│   ├── soil_physics.ts  # Neraca air tanah, profil 6 petak, ADC & aki solar
│   ├── weather.ts       # Open-Meteo (live & historis) + generator tropis prosedural
│   ├── supabase.ts      # Klien REST Supabase (batch, retry, hidrasi)
│   └── types.ts         # Konstanta hardware & tipe bersama
└── tests/
    ├── soil_physics.test.ts
    └── esp32_sim.test.ts
```

## 7. Checklist Validasi di App

1. Jalankan `bun run backfill` lalu `bun run live`.
2. **Home:** `esp32-01` tampil `6/6 online`, 6 petak menampilkan angka beragam dan alami.
3. **Dashboard Grafik `1H` / `1M`:** kurva turun curam di siang panas, landai di malam hari, naik saat hujan/siram, dan berbeda tiap hari & tiap petak.
4. **Kontrol Valve:** tekan **BUKA (30s)** di HP → dalam ≤ 5 detik status berubah `Menunggu ESP32… → Dieksekusi HH:mm` dan status valve langsung **TERBUKA**; 30 detik kemudian otomatis berubah **TERTUTUP** dengan kelembaban naik & tegangan aki pulih — meski interval record sensor 30 menit.
5. **Jangan jalankan bersamaan dengan ESP32 fisik** (kedua penulis akan mengirim data ke `device_id` yang sama).
