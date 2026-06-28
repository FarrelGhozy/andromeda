# 🚀 ANDROMEDA

**A**ndroid **R**outine **M**onitoring **E**lectronic **D**rip **A**utomation  

Sistem Irigasi Tetes Otomatis Berbasis IoT — Monitoring & Kontrol Android  
Program PDB (Program Desa Binaan) — **Desa Merayan**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Platform](https://img.shields.io/badge/Platform-ESP32-blue)
![Backend](https://img.shields.io/badge/Backend-Supabase-orange)
![Mobile](https://img.shields.io/badge/Mobile-Android-brightgreen)

---

## 📖 Tentang ANDROMEDA

**ANDROMEDA** adalah sistem irigasi tetes otomatis berbasis IoT yang dirancang untuk membantu petani di **Desa Merayan** dalam mengoptimalkan penyiraman tanaman — khususnya **benih padi, cabai, dan tanaman hortikultura** — secara efisien, hemat biaya, dan dapat dikendalikan dari jarak jauh melalui smartphone Android.

Sistem ini memanfaatkan **ESP32** sebagai pengendali utama, **sensor kelembaban tanah kapasitif** untuk membaca kondisi tanah, dan **solenoid valve** (kran otomatis) yang memanfaatkan tekanan gravitasi dari **tandon air** yang sudah tersedia di lokasi. Data dikirim ke **Supabase** (cloud gratis) melalui koneksi **4G LTE Router (Huawei B535)** yang ditenagai oleh **aki 100Ah + solar panel 300Wp**.

### 🎯 Masalah → Solusi

| Masalah | Solusi ANDROMEDA |
|---------|------------------|
| Penyiraman manual tidak efisien | Otomatis berdasarkan threshold kelembaban tanah |
| Pemborosan air irigasi | Irigasi tetes presisi — air cuma netes pas dibutuhkan |
| Petani harus ke sawah tiap hari | Monitoring & kontrol dari Android, dari mana aja |
| Biaya WiFi rumahan mahal (Rp 150rb+/bln) | Cukup **Rp 15.000/bulan** via router 4G + paket data |
| Listrik PLN tidak sampai ke sawah | Daya dari **aki 100Ah + solar panel 300Wp** |
| Harus beli pompa air tambahan | Manfaatin **tandon + solenoid valve** — gravity aja cukup |

---

## 🏗️ Arsitektur Sistem

```
                    ┌──────────────────────────┐
                    │      ☀️ SOLAR PANEL       │
                    │         300 Wp            │
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │    AKI 100Ah 12V          │
                    └────────────┬─────────────┘
                                 │ 12V DC
                    ┌────────────▼─────────────┐
                    │  HUAWEI B535-932          │
                    │  4G LTE ROUTER            │
                    │  (WiFi Hotspot)           │
                    └────────────┬─────────────┘
                                 │ WiFi
                    ┌────────────▼─────────────┐
                    │         ESP32             │
                    │  (Deep Sleep ~5µA)        │
                    │                           │
                    │  ┌─────────────────────┐  │
                    │  │ Capacitive Soil     │  │
                    │  │ Sensor v1.2         │  │
                    │  └─────────────────────┘  │
                    │  ┌─────────────────────┐  │
                    │  │ Relay Module 1ch    │  │
                    │  │ ← kontrol 12V DC    │  │
                    │  └──────────┬──────────┘  │
                    └─────────────┼─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │   SOLENOID VALVE 12V NC   │
                    │   (Normally Closed)       │
                    │   Buka/Tutup Aliran Air   │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │     TANDON AIR (ADA)      │
                    │  + Alat Pengisi Otomatis  │
                    └─────────────┬─────────────┘
                                  │ Gravitasi
                    ┌─────────────▼─────────────┐
                    │   DRIP IRRIGATION LINE    │
                    │   Selang + Emitter        │
                    │        ↓  ↓  ↓           │
                    │    Tanaman Padi & Cabe    │
                    └───────────────────────────┘
```

---

## ⚙️ Komponen Hardware

| No | Komponen | Fungsi | Estimasi Harga |
|----|----------|--------|:--------------:|
| 1 | **ESP32 DevKit** | Mikrokontroler (WiFi + Bluetooth built-in) | Rp 65.000 |
| 2 | **Capacitive Soil Sensor v1.2** | Sensor kelembaban tanah (anti korosi) | Rp 35.000 |
| 3 | **Relay Module 1 Channel 5V** | Driver untuk solenoid valve | Rp 12.000 |
| 4 | **Solenoid Valve 12V NC** | Buka/tutup aliran air dari tandon | Rp 50.000 |
| 5 | **Huawei B535-932** | 4G LTE Router (koneksi internet) | Rp 450.000 |
| 6 | **Power Supply 5V/2A** | Daya ESP32 (dari aki via step-down) | Rp 18.000 |
| 7 | **Selang Drip + Dripper** | Distribusi air tetes ke tanaman | Rp 45.000 |
| 8 | **Kabel, Project Box, dll** | Enclosure dan koneksi | Rp 35.000 |
| | | | |
| | **Total Hardware (per titik)** | | **~Rp 710.000** |
| | **Biaya Operasional Bulanan** | Paket data router 4G | **Rp 15.000** |

---

## 💻 Software Stack

| No | Software | Fungsi |
|----|----------|--------|
| 1 | **Arduino IDE / PlatformIO** | Programming ESP32 (C/C++) |
| 2 | **Supabase (Free Tier)** | Backend: PostgreSQL + REST API — **Rp 0/bulan** |
| 3 | **Android Studio (Kotlin)** | Pengembangan aplikasi Android |
| 4 | **Supabase Android SDK** | Sinkronisasi data real-time otomatis |
| 5 | **MPAndroidChart** | Grafik kelembaban historis |

---

## 📱 Fitur Aplikasi Android

| Fitur | Deskripsi |
|-------|-----------|
| **Dashboard Real-time** | Lihat kelembaban tanah terkini + status valve |
| **Kontrol Valve** | Buka/tutup solenoid valve dari HP kapan aja |
| **Mode Otomatis** | Siram otomatis saat tanah kering, berhenti saat basah |
| **Atur Threshold** | Setel batas kering & basah sesuai jenis tanaman |
| **Timer Siram** | Atur durasi valve terbuka (15/30/60 detik) |
| **Grafik Historis** | Riwayat kelembaban harian, mingguan, bulanan |
| **Notifikasi** | Alert saat kelembaban kritis / valve error |

---

## 🔄 Alur Kerja

### Mode Otomatis (Default)

```
ESP32 tidur nyenyak (deep sleep ~5µA)
  ↓ Tiap 30 menit — bangun (0.3 detik)
  ↓ Konek WiFi ke Huawei B535
  ↓ Baca sensor kelembaban
  ↓ HTTP POST → Supabase: {moisture: 65, valve: OFF}
  ↓ HTTP GET ← Supabase: ada pending commands?
  ↓ Cek threshold:
     ├─ Kering (< 70%)  → Relay ON → Solenoid Valve OPEN
     │                    → Air netes dari tandon ke tanaman
     │                    → Tunggu 30 detik → Tutup valve
     └─ Basah (≥ 85%)   → Valve tetap CLOSED
  ↓ Tidur lagi zzz...
```

### Mode Manual (Dari Android)

```
User buka ANDROMEDA App
  ↓ Data auto sync dari Supabase SDK
  ↓ Lihat dashboard: kelembaban 45%, valve CLOSED
User tap "BUKA VALVE" — isi durasi: 30 detik
  ↓ Android POST → Supabase pending_commands: VALVE_ON:30
  ↓ ESP32 bangun → GET pending_commands
  ↓ Relay ON → Solenoid OPEN → Air netes 30 detik
  ↓ Update status ke Supabase
  ↓ Android auto sync → lihat valve: OPEN → CLOSED ✅
```

---

## ⚡ Konsumsi Daya

| Mode | Arus | Daya | Catatan |
|------|:----:|:----:|---------|
| Deep Sleep | ~5 µA | ~0.025 mW | 99,9% waktu |
| Aktif (baca + kirim) | ~80 mA | ~400 mW | ~3 detik tiap 30 menit |
| Solenoid Valve ON | ~500 mA | ~6 W | Hanya saat siram (30-60 dtk) |
| **Rata-rata sistem** | **~0,3 mA** | **~1,5 mW** | **Termasuk siklus valve** |

**Dengan aki 100Ah:**
- Tanpa solar panel: tahan ~138 hari 🔥
- Dengan panel 300Wp: **isi ulang penuh dalam 3-4 jam**

---

## 🗄️ Tabel Database Supabase

| Tabel | Fungsi | Write | Read |
|-------|--------|:-----:|:----:|
| `sensor_readings` | Log kelembaban + timestamp | ESP32 | Android |
| `pending_commands` | Antrian perintah dari Android | Android | ESP32 |
| `system_config` | Threshold, mode, durasi | Android | ESP32 |
| `users` | Autentikasi pengguna | Android | Auth |

---

## 📊 Perbandingan Biaya Internet

| Metode | Biaya Bulanan | Colok Aki? | Stabil 24/7? | Antena Luar? |
|--------|:-----------:|:---------:|:-----------:|:----------:|
| ❌ WiFi ISP Rumahan | **Rp 150-300rb** | ❌ | ✅ | ❌ |
| ⚠️ Mifi Pocket E5577 | Rp 15-30rb | ⚠️ (baterai ngembung) | ❌ | ❌ |
| ⚠️ USB Modem E3372 | Rp 15-30rb | ⚠️ (butuh router) | ✅ | ✅ |
| ✅ **Huawei B535-932** 🔥 | **Rp 15-30rb** | **✅ Langsung 12V** | **✅** | **✅** |

---

## 🗺️ Roadmap

### ✅ Fase 1 — Perancangan (Selesai)
- [x] Survei lokasi Desa Merayan
- [x] Studi literatur + perbandingan komponen
- [x] Perancangan arsitektur sistem
- [x] Proposal teknis (PDF)

### 🔄 Fase 2 — Perakitan Hardware (Sedang Berjalan)
- [ ] Rakit ESP32 + sensor + relay
- [ ] Instalasi solenoid valve di tandon
- [ ] Pasang selang drip irrigation
- [ ] Setup router B535 + antena outdoor
- [ ] Koneksi ke aki + solar panel

### ⏳ Fase 3 — Firmware ESP32
- [ ] Programming WiFi + HTTP client
- [ ] Kalibrasi sensor kelembaban
- [ ] Logika kontrol threshold
- [ ] Mode deep sleep

### ⏳ Fase 4 — Backend Supabase
- [ ] Setup project Supabase
- [ ] Migrasi database schema
- [ ] Uji REST API

### ⏳ Fase 5 — Aplikasi Android
- [ ] UI/UX Dashboard
- [ ] Integrasi Supabase SDK
- [ ] Kontrol valve + mode auto/manual
- [ ] Grafik historis
- [ ] Notifikasi

### ⏳ Fase 6 — Uji Coba Lapangan
- [ ] Deploy di Desa Merayan
- [ ] Kalibrasi threshold sesuai tanaman
- [ ] Evaluasi + laporan akhir

---

## 📁 Struktur Repo

```
andromeda/
├── README.md
├── LICENSE
├── hardware/
│   ├── schematics/        ← Skematik rangkaian
│   ├── pinout.md          ← Pin connections
│   └── bom.md             ← Bill of Materials
├── firmware/
│   ├── src/               ← ESP32 source code
│   ├── lib/               ← Libraries
│   └── config/            ← WiFi, API config
├── android/
│   └── app/               ← Android app source
├── database/
│   └── schema.sql         ← PostgreSQL schema
└── docs/
    └── proposal.pdf       ← Proposal lengkap
```

---

## 👨‍💻 Tim

| Peran | Nama |
|-------|------|
| **Ketua / Pengembang** | Farrel Ghozy Afifudin (452024611053) |
| **Dosen Pembimbing** | ... |

**Prodi:** Teknik Informatika — UNIDA Gontor  
**Program:** PDB (Program Desa Binaan) — **Desa Merayan**

---

## 📄 Lisensi

MIT License — silakan dikembangkan untuk desa lain.

---

## 📞 Kontak

**Farrel Ghozy Afifudin**  
📧 farrelafif05@gmail.com  
🐙 [github.com/FarrelGhozy](https://github.com/FarrelGhozy)

---

> 🌾 *ANDROMEDA — Dari petani, oleh petani, untuk petani.*  
> *Teknologi tepat guna untuk kemandirian pangan Indonesia.*
