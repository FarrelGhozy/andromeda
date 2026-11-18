# Setup ANDROMEDA MVP

Panduan setup cepat untuk menjalankan ANDROMEDA dengan 6 petak.

---

## 1. Setup Supabase

1. Buka [supabase.com](https://supabase.com) dan buat project baru (Free Tier).
2. Buka SQL Editor.
3. Copy paste isi file `database/schema.sql`, lalu run.
4. Setelah sukses, pergi ke **Project Settings → API**.
5. Catat:
   - `Project URL`
   - `anon public`

---

## 2. Konfigurasi Firmware ESP32

### 2.1 Install PlatformIO

```bash
pip install platformio
# atau pakai VSCode extension: PlatformIO IDE
```

### 2.2 Update Config

Buka file `hardware/firmware/include/config.h`, isi:

```cpp
#define WIFI_SSID "nama-wifi-lu"
#define WIFI_PASSWORD "password-wifi-lu"
#define SUPABASE_URL "https://your-project.supabase.co"
#define SUPABASE_ANON_KEY "your-anon-key"
```

### 2.3 Pilih Petak

Ubah baris include di `hardware/firmware/include/config.h`:

```cpp
#include "devices/petak_01.h"   // ganti 01-06 sesuai petak
```

### 2.4 Build & Flash

```bash
cd hardware/firmware
pio run --target upload
pio device monitor
```

Ulangi untuk masing-masing petak (ganti include, flash ulang).

---

## 3. Setup Aplikasi Flutter

### 3.1 Prasyarat

- Flutter SDK terinstal (`flutter --version`).
- Project Supabase sudah jadi dan `database/schema.sql` sudah dijalankan (lihat §1).

### 3.2 Konfigurasi Environment

Credential Supabase dibaca dari file `.env` (paket `flutter_dotenv`) — jangan
tulis credential langsung di kode.

1. Di **root projek**, copy template lalu isi:

   ```bash
   cp .env.example .env
   ```

2. Isi `SUPABASE_URL` dan `SUPABASE_ANON_KEY` dari dashboard Supabase
   (**Project Settings → API** → `Project URL` + `anon public` key).

3. Sync ke folder aplikasi (wajib — Flutter hanya bisa membaca `.env`
   sebagai asset dari dalam `mobile_app/`):

   ```bash
   cp .env mobile_app/.env
   ```

> `mobile_app/.env` hanyalah salinan lokal hasil sync dan di-ignore oleh git.
> Sumber utamanya tetap `.env` di root projek. Jangan pernah commit file
> `.env` yang berisi credential asli. Kalau aplikasi gagal start dengan pesan
> `Supabase belum dikonfigurasi`, berarti langkah sync di atas belum dilakukan.

### 3.3 Mode Mock (data contoh, tanpa Supabase)

Untuk development, demo, atau screenshot — tanpa butuh project Supabase
dan tanpa internet:

1. Di `.env` (root), set:

   ```bash
   APP_DATA_SOURCE=mock
   ```

2. Sync lalu jalankan:

   ```bash
   cp .env mobile_app/.env
   cd mobile_app
   flutter run
   ```

Mode mock menampilkan 6 petak contoh dengan data live simulasi (grafik,
riwayat 7 hari, config). Banner oranye **"MODE MOCK"** selalu tampil di
home sebagai penanda. Semua tombol tetap memberi feedback SnackBar normal
(buka/tutup valve, rename, simpan threshold, batal command), tapi tidak
ada efek ke dunia nyata — perintah valve disimulasikan ESP32
(pending → executed ±2 detik). Cuaca tetap data real (Open-Meteo, gratis).
Kembalikan ke `APP_DATA_SOURCE=supabase` untuk data kebun asli.

### 3.4 Run App

```bash
cd mobile_app
flutter pub get
flutter run
```

---

## 4. Testing dengan cURL

### Kirim data sensor (seolah dari ESP32)

```bash
curl -X POST \
  'https://your-project.supabase.co/rest/v1/sensor_readings' \
  -H "apikey: your-anon-key" \
  -H "Authorization: Bearer your-anon-key" \
  -H "Content-Type: application/json" \
  -d '{"device_id":"petak-01","moisture":2000,"moisture_percent":45,"valve_status":"OFF"}'
```

### Kirim perintah buka valve dari aplikasi

```bash
curl -X POST \
  'https://your-project.supabase.co/rest/v1/pending_commands' \
  -H "apikey: your-anon-key" \
  -H "Authorization: Bearer your-anon-key" \
  -H "Content-Type: application/json" \
  -d '{"device_id":"petak-01","command":"VALVE_ON","duration":30}'
```

### Cek config perangkat

```bash
curl 'https://your-project.supabase.co/rest/v1/system_config?device_id=eq.petak-01' \
  -H "apikey: your-anon-key" \
  -H "Authorization: Bearer your-anon-key"
```

---

## 5. Alur Kerja End-to-End

1. ESP32 bangun dari deep sleep.
2. ESP32 baca sensor, kirim ke `sensor_readings`.
3. ESP32 ambil config dari `system_config`.
4. ESP32 cek `pending_commands`:
   - Kalau ada `VALVE_ON` → buka valve sesuai durasi → tutup.
   - Kalau mode `auto` dan tanah kering → buka valve otomatis.
5. ESP32 tidur lagi sesuai `read_interval`.
6. Flutter app realtime update saat ada data baru.

---

## Catatan Penting

- Kalibrasi sensor: edit nilai `1500` (basah) dan `2700` (kering) di `hardware/firmware/src/sensor.cpp` sesuai hasil uji di lapangan.
- Untuk testing tanpa hardware, gunakan cURL atau langsung insert data lewat Supabase Table Editor.
- Deep sleep membuat ESP32 tidak bisa menerima perintah realtime; perintah ditunggu saat bangun berikutnya.
