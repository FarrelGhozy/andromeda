# Design v0.2 — Cuaca, Jurnal Petani, Rekapan Data & Offline Mode

> Branch: `feat/andromeda-v0.2` · Base: `main` (4291b11) · App version: `0.1.3+4 → 0.2.0+5`
> Status: **DRAFT** (menunggu ACC dari Farrel)

## 1. Ringkasan

Rilis v0.2 menambah 4 kemampuan inti di aplikasi ANDROMEDA:

1. **🌦️ Cuaca** — petani menentukan lokasi lahan secara manual (disimpan lokal), lalu melihat prakiraan cuaca + rekomendasi irigasi dari API gratis (tanpa API key).
2. **📓 Jurnal & Pengetahuan Petani** — catatan kegiatan harian + pustaka artikel pengetahuan sederhana (bahasa petani), tersimpan 100% lokal di HP.
3. **📊 Rekapan Data** — ringkasan semua sensor (semua petak) di halaman utama dengan grafik informatif.
4. **📴 Offline Mode** — aplikasi tetap bisa dibuka tanpa koneksi; ada peringatan di homepage, trigger saat mencoba kontrol valve, dan tampilan data terakhir yang tersimpan.

## 2. Temuan Audit (kondisi kode saat ini)

| Temuan | Dampak |
|---|---|
| Splash screen **menolak masuk** kalau `checkConnection()` gagal (hanya ada tombol "Coba Lagi") | Bertentangan dengan offline mode → harus diubah |
| `connectivity_plus ^6.0.0` sudah ada di pubspec tapi **0 pemakaian** | Tinggal dipakai untuk stream status koneksi |
| `shared_preferences ^2.3.0` sudah ada | Dipakai untuk simpan lokasi cuaca + jurnal + cache snapshot |
| `fl_chart ^0.69.0` sudah ada (dipakai `MoistureChart` di dashboard) | Dikenal baik, dipakai juga untuk rekapan |
| `http ^1.2.0` sudah ada | Dipakai untuk request Open-Meteo |
| `DevicesProvider` sudah menyimpan `_devices` + `_latestReadings` (semua petak) | Basis rekapan "ringkasan" tanpa query tambahan |
| `getHistory()` `SensorRepository` sudah benar (UTC, fix #32) | Dipakai rekapan historis per petak |
| Home screen hanya berisi daftar ESP32 card | Perlu ditambah entry point ke fitur baru + banner offline + kartu rekapan |

**Keputusan API cuaca:** 🌤️ **Open-Meteo** — gratis, **tanpa API key**, tanpa registrasi, lisensi open data, dua endpoint yang dibutuhkan:
- Geocoding: `https://geocoding-api.open-meteo.com/v1/search?name=<nama>&count=8&language=id`
- Forecast: `https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m&timezone=auto`
- Alternatif (perlu key/registrasi): OpenWeatherMap, WeatherAPI, BMKG data.go.id — **tidak direkomendasikan** untuk tugas kuliah.

## 3. Arsitektur Baru

```
mobile_app/lib/
├── services/
│   ├── connectivity_service.dart      [BARU] wrapper connectivity_plus
│   ├── weather_service.dart           [BARU] Open-Meteo (geocode + forecast)
│   ├── local_store.dart               [BARU] SharedPreferences wrapper (lokasi, jurnal, cache snapshot)
│   └── cache_repository.dart          [BARU] snapshot devices+readings utk offline
├── providers/
│   ├── connectivity_provider.dart     [BARU] status koneksi (stream) — dipakai global
│   ├── weather_provider.dart          [BARU] lokasi + data cuaca
│   └── journal_provider.dart          [BARU] CRUD jurnal lokal
├── models/
│   ├── weather_location.dart          [BARU] nama, lat, lon, waktu simpan
│   ├── weather_data.dart              [BARU] current + daily forecast
│   └── journal_entry.dart             [BARU] id, tanggal, kategori, judul, isi
├── screens/
│   ├── weather_screen.dart            [BARU] cari lokasi + tampil forecast
│   ├── journal_screen.dart            [BARU] list jurnal
│   ├── journal_edit_screen.dart       [BARU] tambah/edit entri
│   └── home_screen.dart               [EDIT] banner offline + kartu rekapan + menu fitur
├── widgets/
│   ├── offline_banner.dart            [BARU] banner "Offline — data tersimpan"
│   ├── weather_card.dart              [BARU] kartu cuaca di home (opsional)
│   ├── summary_cards.dart             [BARU] kartu rekapan (petak, online, avg moisture)
│   └── summary_chart.dart             [BARU] grafik rekapan (fl_chart)
├── routes.dart                        [EDIT] + /weather, /journal, /journal-edit
└── main.dart                          [EDIT] daftarkan provider baru
```

### 3.1 Offline Mode (fondasi — dikerjakan pertama)

**Alur baru splash screen:**
1. Tampilkan loading → cek koneksi Supabase.
2. **Online** → muat data seperti sekarang, lanjut home.
3. **Offline** → **tetap masuk home** (ubah perilaku lama), `ConnectivityProvider` mengubah status, `CacheRepository` memuat snapshot terakhir dari SharedPreferences (devices + latest readings + timestamp snapshot).

**Cache snapshot (CacheRepository):**
- Simpan saat online: setiap `DevicesProvider.refreshReadings()` sukses → tulis `{devices: [...], readings: {...}, savedAt: ISO}` ke SharedPreferences.
- Muat saat offline: restore ke provider → UI tampil seperti biasa + banner "Offline — data tersimpan (kena/non tgl)".
- Ukuran kecil (6 petak × 1 reading) → SharedPreferences cukup, tidak perlu sqflite.

**Trigger offline:**
- **Homepage**: `OfflineBanner` di atas list (merah, ikon `cloud_off`) + ikon status di AppBar.
- **Tombol valve (katup)** di detail petak: saat offline → tombol disabled + SnackBar "Offline — perintah valve tidak bisa dikirim".
- **Sensor**: kartu petak & gauge menampilkan badge "data tersimpan" (bukan "offline ESP32" yang menyesatkan) + nilai dari snapshot terakhir.

### 3.2 Fitur Cuaca

**Alur:**
1. Masuk `WeatherScreen` → jika belum ada lokasi tersimpan → halaman pencarian lokasi (TextField + tombol cari).
2. `WeatherService.searchLocation(q)` → Open-Meteo geocoding → list hasil (nama, negara, lat, lon, admin1, population).
3. Petani pilih lokasi → `WeatherLocation` disimpan ke SharedPreferences via `LocalStore` (`weather_location` key).
4. `WeatherService.getForecast(lat, lon)` → current (suhu, kelembaban, angin, weather_code) + daily 7 hari (max/min suhu, probabilitas hujan, mm hujan).
5. UI: kartu "Hari Ini" (ikon cuaca + suhu + kelembaban + angin + kode cuaca WMO→teks Indonesia), lalu daftar 7 hari.
6. **Rekomendasi irigasi sederhana** (nilai tambah): 
   - Besok probabilitas hujan ≥ 60% → "Hujan diperkirakan — pertimbangkan tunda penyiraman"
   - Suhu max ≥ 33°C & probabilitas hujan < 20% → "Panas & kering — kelembaban cepat turun, cek jadwal siram"
   - Selain itu → "Kondisi normal"

**Model:**
```dart
class WeatherLocation { String name; String? admin1; String country; double lat; double lon; DateTime savedAt; }
class WeatherData {
  CurrentWeather current;         // temp, humidity, wind, code
  List<DailyWeather> daily;       // 7 hari: date, code, tMax, tMin, precipProb, precipMm
  String irrigationAdvice;        // hasil rekomendasi irigasi
}
```

**Catatan:** geocoding Open-Meteo (GeoNames) menjangkau kota/kecamatan besar di Indonesia. Desa kecil mungkin tidak muncul → fallback: hasil terdekat dari pencarian (mis. "Banyuwangi") atau input lat/lon manual (TBD-3).

### 3.3 Jurnal & Pengetahuan Petani (lokal 100%)

> **Pembaruan dari feedback Farrel:** bukan sekadar "buku catatan kaku" — fitur ini
> dua-in-satu: **(A) Catatan Kegiatan** (log harian petani) + **(B) Pustaka Pengetahuan**
> (artikel pendek informatif, bahasa sederhana ala nasehat sesama petani, bukan
> tulisan akademik). Keduanya tersimpan/terbaca 100% offline.

#### A. Catatan Kegiatan (log harian)
**Alur:**
1. `JournalScreen` → tab **"Catatan Saya"**: daftar entri dikelompokkan per tanggal (terbaru di atas), FAB "Tambah Catatan".
2. `JournalEditScreen` → form: tanggal (default hari ini), kategori (dropdown), judul, isi (multiline). Simpan/Hapus.
3. Data disimpan via `LocalStore` sebagai JSON list di SharedPreferences (`journal_entries` key) — cukup untuk ratusan entri teks, tanpa dependency baru.

**Model:**
```dart
class JournalEntry {
  String id;            // timestamp-based
  DateTime date;        // tanggal kejadian (bisa berbeda dari created)
  String category;      // penyiraman | pemupukan | hama-penyakit | panen | lainnya
  String title;
  String content;
  DateTime createdAt;
}
```

**Kategori (referensi praktik pertanian umum):**
- 💧 Penyiraman — jadwal, durasi, kondisi tanah
- 🌱 Pemupukan — jenis pupuk, dosis, cara aplikasi
- 🐛 Hama & Penyakit — gejala, tindakan
- 🌾 Panen — tanggal, hasil, kualitas
- 📝 Lainnya — pengamatan umum, cuaca, catatan harga

#### B. Pustaka Pengetahuan Petani (artikel bundled)
**Konsep:** pustaka artikel pendek yang **membantu petani mengambil keputusan**
(kapan siram, pupuk apa, hama apa ini?) — ditulis dengan bahasa sehari-hari,
kalimat pendek, tanpa istilah asing, relevan dengan sistem ANDROMEDA.

**Alur:**
1. Tab **"Pustaka"** di `JournalScreen` → daftar artikel (kategori + judul).
2. Buka artikel → halaman baca (`JournalArticleScreen`), teks dengan heading &
   poin-poin agar enak dibaca di HP.
3. Konten = file JSON bundled di asset app (`assets/data/tips_petani.json`),
   dibaca offline tanpa internet, diperbarui tiap rilis.
4. (Opsional, TBD-6) petani bisa menandai artikel "disimpan".

**Daftar artikel awal (±10, bahasa sederhana, temanya sesuai irigasi ANDROMEDA):**
- 💧 "Angka kelembaban di aplikasi itu artinya apa?" — baca % moisture, kapan siram/tidak
- 💧 "Kapan lahan perlu disiram?" — tanda-tanda tanah kering vs jadwal
- 🚿 "Tips hemat air pakai irigasi tetes" — durasi, frekuensi, hindari penguapan
- 🌱 "Pupuk itu bukan cuma NPK" — jenis pupuk umum & fungsinya (dasar)
- 🌱 "Kapan dan berapa banyak memupuk?" — panduan dosis sederhana per fase tanam
- 🐛 "Hama umum di musim kemarau & hujan" — pengenalan + cara sederhana
- 🛠️ "Sensor kelembaban bermasalah?" — indikasi error, cek kabel/baterai
- 🔋 "Merawat aki & panel surya sistem irigasi" — umur panel/aki
- 🌾 "Mencatat yang benar = panen yang terencana" — kenapa catatan penting
- ❄️ "Cuaca ekstrem: apa yang harus dilakukan" — hujan deras/panas ekstrem

> Penulisan konten dilakukan saat implementasi Fase 2: bahasa Indonesia sederhana
> (target pembaca: petani Desa Merayan), 150–300 kata per artikel.

**Model:**
```dart
class JournalArticle {
  String id;
  String category;      // penyiraman | pemupukan | hama | perawatan | lainnya
  String title;
  String summary;       // 1–2 kalimat di daftar
  List<ArticleSection> sections; // heading + body, di-render sebagai kartu berjudul
}
```

### 3.4 Rekapan Data di Halaman Utama

**Alur:**
1. Home screen mendapat 2 bagian: (a) **Kartu Rekapan** (ringkasan live dari `DevicesProvider` tanpa query tambahan), (b) **Daftar lahan** seperti sekarang.
2. Ringkasan: jumlah ESP32/lahan, total petak, petak online, rata-rata kelembaban semua petak (hanya yang fresh), petak dengan sensor fault/error, valve sedang terbuka.
3. **Grafik informatif** (fl_chart):
   - **Bar chart**: rata-rata kelembaban % per petak (semua petak sekali lihat) — beda warna berdasarkan status (kering/basah/fault).
   - **Ringkasan status**: petak online vs offline (donut/pie kecil) — opsional.
4. Data rekapan = `DevicesProvider.latestFor()` untuk semua device → dihitung via `HomeSummaryProvider` (atau computed getter di provider) → otomatis realtime karena source-nya sama.
5. Rekapan historis per petak tetap di dashboard (tidak diubah).

## 4. Keputusan yang Perlu Dikonfirmasi (TBD)

### TBD-1 — Nama branch
- **(a) `feat/andromeda-v0.2`** (rekomendasi — sudah dibuat) — satu branch untuk seluruh rilis v0.2
- (b) `feat/cuaca` — khusus cuaca saja (tidak mencakup jurnal/rekapan/offline)

### TBD-2 — Penyimpanan jurnal
- **(a) SharedPreferences JSON** (rekomendasi) — tanpa dependensi baru, cukup utk ratusan entri teks
- (b) `sqflite` — database SQL lokal, lebih "proper" utk skala besar, tambah dependency + migrasi

### TBD-3 — Pencarian lokasi cuaca
- **(a) Search teks geocoding + fallback pilih hasil terdekat** (rekomendasi) — tanpa dependency baru
- (b) Tambah peta (flutter_map/OSM) utk pin manual — lebih akurat, tapi tambah dependency & scope cukup besar
- (c) Input lat/lon manual sebagai fallback tambahan

### TBD-4 — Foto di jurnal
- **(a) Tanpa foto di v0.2** (rekomendasi) — teks dulu, foto bisa fase berikutnya
- (b) Dengan foto (path_provider + image_picker) — scope bertambah signifikan

### TBD-5 — Seberapa agresif cache offline
- **(a) Snapshot terakhir saja** (rekomendasi) — devices + latest readings semua petak, 1 snapshot
- (b) Snapshot + histori grafik per petak (lebih besar, simpan juga riwayat s/d 100 baris/petak)

### TBD-6 — Sumber konten "Pustaka Pengetahuan"
- **(a) Bundled di app** (rekomendasi) — artikel ditulis saat development (`assets/data/tips_petani.json`), bisa dibaca offline, diperbarui tiap rilis
- (b) Bundled + petani bisa menambah artikel sendiri (disimpan lokal)
- (c) Ditarik dari API online — butuh server, bertentangan dengan offline mode

### ✅ Status Keputusan (per 17 Agu 2026 — dikunci Farrel)
| TBD | Keputusan | Catatan |
|---|---|---|
| TBD-1 | **(a)** `feat/andromeda-v0.2` | Sudah dibuat dari main |
| TBD-2 | **(a)** SharedPreferences JSON | Tanpa dependency baru |
| TBD-3 | **(a)** Search teks geocoding + fallback hasil terdekat | Tanpa peta/input manual di v0.2 |
| TBD-4 | **(a)** Tanpa foto di v0.2 | Foto = fase berikutnya |
| TBD-5 | **(a)** Snapshot terakhir saja | Devices + latest readings |
| TBD-6 | **(a)** Bundled di app | **Dikonfirmasi Farrel langsung** |

## 5. Rencana Board Issues (setelah ACC)

1. **#epic** — Epic v0.2: Cuaca, Jurnal & Pengetahuan, Rekapan & Offline Mode (dibuat terakhir, referensi semua issue)
2. **#1 Decision** — Jawab TBD-1..6 (menghalangi semua fase)
3. **#2 Fase 0 — Fondasi Offline**: ConnectivityService/Provider, LocalStore, CacheRepository, ubah splash (offline → tetap masuk), banner home, trigger valve/sensor, daftarkan provider di main
4. **#3 Fase 1 — Fitur Cuaca**: model, WeatherService, WeatherProvider, WeatherScreen, simpan lokasi lokal, rekomendasi irigasi
5. **#4 Fase 2 — Jurnal & Pengetahuan Petani**: catatan kegiatan (CRUD lokal) + pustaka artikel bundled (asset JSON + halaman baca), kategori, route
6. **#5 Fase 3 — Rekapan Data**: summary provider, kartu rekapan, bar chart per petak di home
7. **#6 Fase 4 — Rilis v0.2**: bump versi 0.2.0+5, update README, build APK release, upload release GitHub, close milestone

Setiap issue berisi: Tujuan, Prasyarat (#N), Acceptance Criteria terukur, Langkah Kerja checklist, Referensi (design doc ini), Pitfall. Komit per issue dengan referensi `(#N)`, close issue dengan bukti hash komit.

## 6. Pitfall yang Sudah Diketahui (dari audit)

- **Realtime Supabase gagal saat offline** → `DevicesProvider._loadInitialDevices()` dan `refreshReadings()` sudah punya catch; pastikan fallback cache dipanggil di catch, dan `_checkReady()` tetap jalan agar splash tidak menggantung.
- **Jangan timpa cache dengan state kosong**: saat offline, `getDevicesStream()` bisa emit `[]` → jangan simpan `[]` sebagai snapshot (cek `savedAt` & isEmpty).
- **`connectivity_plus` di emulator**: status bisa berubah-ubah; kombinasikan dengan hasil `checkConnection()` (Supabase) sebagai sumber kebenaran "benar-benar online" — jangan hanya andalkan connectivity stream.
- **Stamp waktu snapshot**: tampilkan "Data tersimpan Jumat, 14:32" — user harus tahu kapan data terakhir diambil.
- **Open-Meteo timezone**: gunakan `timezone=auto` agar jam/tanggal forecast cocok dengan WIB; simpan `utc_offset_seconds` dari respons.
- **fl_chart bar chart**: reuse styling yang sudah ada di `MoistureChart` (warna grid adaptif tema — fix #27) agar konsisten dark/light mode.
- **Versi app**: ikuti `release_guide.md` (SemVer + codename). v0.2.0, codename diusulkan: **"CUACA"** (atau sesuai TBD Farrel).