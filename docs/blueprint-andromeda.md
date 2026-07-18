# 📋 Perencanaan Matang & Detail — ANDROMEDA

**Android Routine Monitoring Electronic Drip Automation**  
Sistem Irigasi Tetes Otomatis Berbasis IoT  
Program PDB (Program Desa Binaan) — **Desa Merayan**

> **Versi:** 1.0  
> **Tanggal:** 18 Juli 2026  
> **Penulis:** Farrel Ghozy Afifudin  
> **Status:** Perencanaan

---

## 📑 Daftar Isi

1. [Ringkasan Eksekutif](#ringkasan-eksekutif)
2. [Arsitektur Sistem](#arsitektur-sistem)
3. [Hardware — Perangkat Keras](#hardware--perangkat-keras)
4. [Firmware ESP32](#firmware-esp32)
5. [Backend Supabase](#backend-supabase)
6. [Aplikasi Flutter](#aplikasi-flutter)
7. [Sistem Daya & Internet](#sistem-daya--internet)
8. [Instalasi & Wiring Lapangan](#instalasi--wiring-lapangan)
9. [Kalibrasi & Threshold Tanaman](#kalibrasi--threshold-tanaman)
10. [Pengujian & Validasi](#pengujian--validasi)
11. [Roadmap & Timeline](#roadmap--timeline)
12. [Anggaran Biaya](#anggaran-biaya)
13. [Daftar Risiko & Mitigasi](#daftar-risiko--mitigasi)

---

## Ringkasan Eksekutif

### Latar Belakang

ANDROMEDA adalah solusi irigasi tetes otomatis untuk petani di **Desa Merayan**. Sistem ini mengatasi masalah utama:

1. **Efisiensi air** — Irigasi tetes menghemat air hingga 60% dibanding penyiraman manual
2. **Otomatisasi** — Petani tidak perlu ke sawah setiap hari
3. **Biaya terjangkau** — Hanya Rp 15.000/bulan untuk internet + Rp 710.000/unit hardware
4. **Off-grid** — Tenaga surya + aki, tanpa listrik PLN

### Target Pengguna

| Segmen | Detail |
|--------|--------|
| Petani utama | Petani padi & cabai di Desa Merayan |
| Lahan | 6 petak (3 di Lahan A, 3 di Lahan B) |
| Tanaman utama | Padi, cabai, hortikultura |

### Prinsip Desain

| Prinsip | Penerapan |
|---------|-----------|
| **Sederhana** | Petani gapai teknologi dengan HP Android |
| **Hemat** | Biaya operasional hanya Rp 15rb/bln |
| **Tangguh** | Off-grid, deep sleep, solenoid NC fail-safe |
| **Terbuka** | Source code open-source (MIT), bisa dikopi desa lain |

---

## Arsitektur Sistem

### Diagram Arsitektur End-to-End

```
┌────────────────────────────────────────────────────────────────────────────┐
│                           ANDROMEDA — SYSTEM ARCHITECTURE                  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        ☁️ CLOUD LAYER                                │  │
│  │                   Supabase (PostgreSQL + REST)                       │  │
│  │                                                                      │  │
│  │  ┌────────────────┐  ┌──────────────────┐  ┌────────────────────┐   │  │
│  │  │ sensor_readings│  │ pending_commands │  │   system_config    │   │  │
│  │  │ ─ log data     │  │ ─ antrian perintah│  │ ─ konfigurasi      │   │  │
│  │  │   kelembaban   │  │   dari aplikasi  │  │   threshold/mode   │   │  │
│  │  └───────┬────────┘  └────────┬─────────┘  └────────┬───────────┘   │  │
│  │          │                    │                      │              │  │
│  │  ┌───────▼────────────────────▼──────────────────────▼───────────┐  │  │
│  │  │              Realtime Publication (WebSocket)                  │  │  │
│  │  └───────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                               │            ▲                               │
│                    ┌──────────┘            │                               │
│                    │ HTTP REST             │ HTTP REST                      │
│                    ▼                       │                               │
│  ┌──────────────────────────────┐ ┌────────────────────────────────────┐   │
│  │     📶 EDGE LAYER            │ │     📱 MOBILE LAYER                │   │
│  │                              │ │                                    │   │
│  │  Huawei B535-932             │ │  Flutter App (Android)             │   │
│  │  4G LTE Router               │ │                                    │   │
│  │                              │ │  ┌──── Dashboard Realtime ────┐   │   │
│  │  ┌────────────────────────┐  │ │  │ Kelembaban, status valve   │   │   │
│  │  │   6 × ESP32 DevKit      │  │ │  ├──── Kontrol Valve ────────┤   │   │
│  │  │  (1 per petak)          │  │ │  │ Manual: BUKA/TUTUP        │   │   │
│  │  │  WiFi station mode      │  │ │  ├──── Mode ─────────────────┤   │   │
│  │  │  Deep sleep ~5µA        │  │ │  │ Auto / Manual             │   │   │
│  │  │                         │  │ │  ├──── Atur ─────────────────┤   │   │
│  │  │  ┌──────────────────┐   │  │ │  │ Threshold, timer, interval│   │   │
│  │  │  │ Capacitive Soil  │   │  │ │  ├──── Grafik ───────────────┤   │   │
│  │  │  │ Sensor v1.2      │   │  │ │  │ Riwayat harian/mingguan  │   │   │
│  │  │  └──────────────────┘   │  │ │  └──────────────────────────┘   │   │
│  │  │  ┌──────────────────┐   │  │ └────────────────────────────────────┘   │
│  │  │  │ Solenoid Valve   │   │  │                                          │
│  │  │  │ 12V NC           │   │  │                                          │
│  │  │  └──────────────────┘   │  │                                          │
│  │  └────────────────────────┘  │                                          │
│  └──────────────────────────────┘                                          │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        ⚡ POWER LAYER                                 │  │
│  │                                                                      │  │
│  │  Solar Panel 300Wp ──→ SCC 20A ──→ Aki 100Ah 12V ──→ Step-down 5V   │  │
│  │                                       ├── 12V ──→ Router B535        │  │
│  │                                       ├── 12V ──→ Solenoid Valve     │  │
│  │                                       └── 5V  ──→ ESP32 + Relay      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

### Alur Data Lengkap

#### Siklus Normal (Otomatis — Setiap 30 Menit)

```
WAKTUNYA NYIRAM! ⏰
     │
     ├─ [00:00.000] ESP32 bangun dari deep sleep
     │
     ├─ [00:00.005] Inisialisasi: pinMode, Serial, valve init (CLOSED)
     │
     ├─ [00:00.010] 🌐 Konek WiFi ke Huawei B535
     │     ├─ Success → Lanjut
     │     └─ Failed  → Deep sleep, coba 30 menit lagi
     │
     ├─ [00:01.000] 🌱 Baca sensor kelembaban (analogRead GPIO 34)
     │     └─ raw: 2200 → percent: 42.5%
     │
     ├─ [00:01.050] ⚙️ GET /system_config?device_id=eq.petak-01
     │     └─ {mode: "auto", threshold_dry: 30, threshold_wet: 70, duration: 30s}
     │
     ├─ [00:01.100] 📋 GET /pending_commands?device_id=eq.petak-01&status=eq.pending
     │     └─ [] (tidak ada perintah)
     │
     ├─ [00:01.150] 🤔 Cek threshold:
     │     └─ 42.5% > 30% (tidak kering) → Valve tetap CLOSED ✅
     │
     ├─ [00:01.200] ✅ Pastikan valve CLOSED (safety)
     │
     ├─ [00:01.210] 📤 POST /sensor_readings
     │     └─ {device_id: "petak-01", moisture: 2200, percent: 42.5, valve: "OFF"}
     │
     ├─ [00:01.300] 📴 Matikan WiFi + mode WIFI_OFF
     │
     └─ [00:01.310] 💤 Deep sleep 1800 detik (30 menit)
           └─ Konsumsi: ~5µA zzz...
```

#### Siklus Penyiraman (Tanah Kering)

```
WAKTUNYA NYIRAM! ⏰
     │
     ├─ ... (sama sampai cek sensor)
     │
     ├─ [00:01.150] 🤔 Cek threshold:
     │     └─ 22.5% < 30% (KERING!) → Buka valve!
     │
     ├─ [00:01.200] 💧 Buka solenoid valve (Relay HIGH)
     │     └─ Air netes dari tandon ke tanaman selama 30 detik
     │
     ├─ [00:31.200] 🔒 Tutup valve (Relay LOW)
     │     └─ Valve NC → otomatis tertutup
     │
     ├─ [00:31.210] 🌱 Baca sensor lagi (post-valve)
     │     └─ percent: 55.5% (udah basah)
     │
     ├─ [00:31.300] 📤 POST /sensor_readings
     │     └─ {..., valve_status: "ON"}
     │
     └─ [00:31.400] 💤 Deep sleep zzz...
```

#### Perintah Manual dari Aplikasi

```
👨‍🌾 USER BUKA APLIKASI ANDROMEDA
     │
     ├─ [00:00] Aplikasi sync realtime dari Supabase
     │     └─ Lihat: petak-01, moisture 22.5%, valve CLOSED
     │
     ├─ [00:05] Tap tombol "BUKA VALVE" → isi durasi: 15 detik
     │
     ├─ [00:06] Flutter POST → pending_commands
     │     └─ {device_id: "petak-01", command: "VALVE_ON", duration: 15}
     │
     ├─ [00:XX] ⏳ ESP32 masih tidur... (tunggu sampai siklus berikutnya)
     │
     ├─ [00:30:00] ESP32 bangun, GET pending_commands
     │     └─ [{id: 42, command: "VALVE_ON", duration: 15}]
     │
     ├─ [00:30:01] 💧 Buka valve 15 detik
     │
     ├─ [00:30:16] 🔒 Tutup valve
     │
     ├─ [00:30:17] PATCH pending_commands → status: "executed"
     │
     ├─ [00:30:18] 📤 POST sensor_readings → valve: "ON"
     │
     └─ [00:30:19] 💤 Tidur lagi
                            
👉 USER LIHAT NOTIFIKASI: "Valve petak-01 telah terbuka selama 15 detik ✅"
```

---

## Hardware — Perangkat Keras

### Bill of Materials (1 Petak)

| No | Komponen | Qty | Harga | Fungsi |
|:--:|----------|:---:|:-----:|--------|
| 1 | **ESP32 DevKit 30 Pin** | 1 | Rp 65.000 | Mikrokontroler utama |
| 2 | **Capacitive Soil Sensor v1.2** | 1 | Rp 35.000 | Sensor kelembaban tanah (anti korosi) |
| 3 | **Relay Module 1ch 5V Optocoupler** | 1 | Rp 12.000 | Driver solenoid valve |
| 4 | **Solenoid Valve 12V NC 1/2"** | 1 | Rp 50.000 | Kran otomatis (fail-safe NC) |
| 5 | **Power Supply Step-down 12V→5V/2A** | 1 | Rp 18.000 | Daya ESP32 dari aki |
| 6 | **LED Indikator 5mm (biru+merah)** | 2 | Rp 2.000 | Status power & error |
| 7 | **Resistor 220Ω** | 2 | Rp 1.000 | Untuk LED |
| 8 | **Kapasitor 100nF Ceramic** | 1 | Rp 1.000 | Filter ADC sensor |
| 9 | **Project Box 200×150×100mm** | 1 | Rp 45.000 | Enclosure panel |
| 10 | **Kabel Belden/UTP Cat5e** | 20m | Rp 120.000 | Sensor → ESP32 (jarak jauh) |
| 11 | **Kabel NYMHY 2×1.5mm** | 10m | Rp 40.000 | Power 12V valve & router |
| 12 | **Terminal Block 12 pin** | 2 | Rp 12.000 | Koneksi rapi dalam box |
| 13 | **Selang Drip PE 16mm** | 20m | Rp 50.000 | Distribusi air tetes |
| 14 | **Dripper/Emitter** | 10 pcs | Rp 15.000 | Penetes air ke tanaman |
| 15 | **Fitting Selang (Tee, Elbow, dll)** | 1 set | Rp 40.000 | Sambungan selang |
| | **Total 1 Petak** | | **~Rp 506.000** | |

### Investasi Bersama (Semua Petak)

| No | Komponen | Qty | Harga | Catatan |
|:--:|----------|:---:|:-----:|---------|
| 1 | **Huawei B535-932 4G LTE Router** | 1 | Rp 450.000 | Untuk 6 petak (1 router) |
| 2 | **Aki Kering 100Ah (Yuasa NS70)** | 1 | Rp 1.100.000 | Semua petak & router |
| 3 | **Solar Panel 300Wp Polycrystalline** | 1 | Rp 1.200.000 | Isi ulang aki |
| 4 | **Solar Charge Controller 20A** | 1 | Rp 125.000 | Atur pengisian aki |
| 5 | **MCB 1 Phase 6A** | 1 | Rp 35.000 | Pengaman listrik |
| 6 | **Kabel NYMHY 2×2.5mm (power)** | 30m | Rp 150.000 | Aki → router & tiap petak |
| 7 | **Kabel Solar Panel 4mm²** | 10m | Rp 100.000 | Panel → SCC |
| 8 | **Aksesoris (kabel ties, duct tape, dll)** | 1 set | Rp 50.000 | Rapiin instalasi |
| 9 | **Antena Outdoor 4G** | 1 | Rp 150.000 | Sinyal 4G maksimal |
| | **Total Investasi Bersama** | | **~Rp 3.360.000** | |

### Total Biaya Keseluruhan

| Item | Biaya |
|------|:-----:|
| 6 Petak × Rp 506.000 | Rp 3.036.000 |
| Investasi Bersama | Rp 3.360.000 |
| **Grand Total** | **~Rp 6.396.000** |
| **Biaya Operasional/Bulan** | **Rp 15.000** (paket data) |

### Wiring Diagram Panel ESP32 (1 Petak)

```
┌───────────────────────────────────────────────────┐
│                  PROJECT BOX                       │
│                                                    │
│  ┌────────────────────────────────────────────┐   │
│  │              ESP32 DevKit                  │   │
│  │                                            │   │
│  │  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────────┐  │   │
│  │  │GPIO│ │GPIO│ │GPIO│ │3.3V│ │  5V    │  │   │
│  │  │ 34 │ │ 26 │ │  2 │ │    │ │        │  │   │
│  │  │IN  │ │OUT │ │LED │ │OUT │ │USB/5V  │  │   │
│  │  └─┬──┘ └─┬──┘ └────┘ └────┘ └────────┘  │   │
│  └────┼──────┼────────────────────────────────┘   │
│       │      │                                     │
│  ┌────▼──────▼────┐                               │
│  │ Terminal Block │                               │
│  │                │                               │
│  │ [1] Sensor IN  │◄──── Sensor (UTP 20m)         │
│  │ [2] 3.3V Out   │───→ Sensor VCC                │
│  │ [3] GND        │───→ Sensor & Relay            │
│  │ [4] Relay IN   │───→ Relay Module              │
│  │ [5] 5V Out     │───→ Relay VCC                 │
│  │ [6] GND        │───→ Relay GND                 │
│  │ [7] 12V In (+) │◄──── PSU Step-down 5V         │
│  │ [8] GND        │◄──── PSU GND                  │
│  └───────────┬────┘                               │
│              │                                     │
│  ┌───────────▼──────────────┐                     │
│  │     Step-Down 12V→5V    │                     │
│  │        LM2596 DC-DC     │                     │
│  │       Input: 12V        │                     │
│  │       Output: 5V/2A     │                     │
│  └───────────┬──────────────┘                     │
│              │ 12V dari Aki                       │
│              │ (via MCB 6A)                       │
└──────────────┼────────────────────────────────────┘
               │
      ┌────────▼────────┐
      │     Aki 100Ah   │
      │      12V DC     │
      └────────┬────────┘
               │
      ┌────────▼────────┐
      │     SCC 20A     │
      │  Solar Charge   │
      │   Controller    │
      └────────┬────────┘
               │
      ┌────────▼────────┐
      │ Solar Panel     │
      │ 300Wp           │
      └─────────────────┘
```

### Wiring Sensor Kelembaban (Jarak Jauh — 20m)

```
┌───────────────────────┐          UTP Cat5e (20m)         ┌──────────────────┐
│      ESP32 Box        │                                   │  Sensor Box      │
│                       │                                   │                  │
│  ESP32 GPIO 34 ───────┼───── Orange (Pin 1) ──────────────┤ Sensor OUT       │
│  ESP32 3.3V    ───────┼───── Blue   (Pin 4) ──────────────┤ Sensor VCC       │
│  ESP32 GND     ───────┼───── Brown  (Pin 8) ──────────────┤ Sensor GND       │
│  Kapasitor 100nF      │                                   │                  │
│  GPIO34 ───┼── GND    │               ┌──────────────────┐│                  │
│            ↓          │               │ Sensor v1.2      ││                  │
│         100nF         │               │ ┌──────────────┐ ││                  │
│           ═══         │               │ │              │ ││                  │
│                       │               │ │ ═══════════  │ ││  Tanah           │
│  * UTP yang nggak     │               │ │ ═══════════  │ ││  ════════        │
│    dipakai di-         │               │ └──────────────┘ ││                  │
│    ground-in di        │               └──────────────────┘│                  │
│    kedua ujung         │                                   └──────────────────┘
└───────────────────────┘
```

### Wiring Relay + Solenoid Valve

```
┌──────────────┐          ┌──────────────────┐          ┌──────────────────┐
│   ESP32      │          │ Relay Module 1ch │          │ Solenoid Valve   │
│              │          │    5V Opto       │          │    12V NC        │
│  GPIO 26 ────┼──────────┤ IN               │          │                  │
│  5V      ────┼──────────┤ VCC              │          │                  │
│  GND     ────┼──────────┤ GND              │          │                  │
│              │          │                  │          │                  │
│              │          │ COM ─────────────┼──────────┤ (+) 12V dari Aki│
│              │          │ NO  ─────────────┼──────────┤ (+) Solenoid     │
│              │          │                  │          │ (-) Solenoid ──→ │
│              │          │                  │          │     GND Aki      │
└──────────────┘          └──────────────────┘          └──────────────────┘

CATATAN:
- Relay HIGH (GPIO 26 = 1) → NO terhubung ke COM → Valve TERBUKA
- Relay LOW  (GPIO 26 = 0) → NO terputus        → Valve TERTUTUP (NC)
- Jika ESP32 mati/reset → GPIO LOW → Relay LOW → Valve NC → TERTUTUP ✅
```

---

## Firmware ESP32

### Arsitektur Perangkat Lunak

```
hardware/firmware/
├── platformio.ini
├── include/
│   ├── config.h                ← WiFi SSID, Supabase URL/key, PIN
│   ├── wifi_manager.h          ← connectWiFi(), disconnectWiFi()
│   ├── sensor.h                ← SensorReading struct, readSensor()
│   ├── valve.h                 ← initValve(), openValve(), closeValve()
│   ├── supabase_client.h       ← SystemConfig, PendingCommand, HTTP API
│   ├── deep_sleep.h            ← goToSleep()
│   └── devices/
│       ├── petak_01.h          ← "petak-01"
│       ├── petak_02.h          ← "petak-02"
│       ├── petak_03.h          ← "petak-03"
│       ├── petak_04.h          ← "petak-04"
│       ├── petak_05.h          ← "petak-05"
│       └── petak_06.h          ← "petak-06"
└── src/
    ├── main.cpp                ← Siklus utama
    ├── wifi_manager.cpp        ← Koneksi WiFi
    ├── sensor.cpp              ← Baca ADC → moisture%
    ├── valve.cpp               ← Kontrol relay
    ├── supabase_client.cpp     ← HTTP client
    └── deep_sleep.cpp          ← Deep sleep
```

### State Machine Detail

```
                    ┌──────────┐
                    │  RESET   │
                    └────┬─────┘
                         │
                    ┌────▼─────┐
             ┌──────┤  SETUP   ├──────┐
             │      └────┬─────┘      │
             │           │            │
             │      ┌────▼─────┐      │
             │      │  WiFi    │      │
             │      │ Connect  │      │
             │      └────┬─────┘      │
             │           │            │
             │     ┌─────▼─────┐      │
             │     │  Sensor   │      │
             │     │  Read     │      │
             │     └─────┬─────┘      │
             │           │            │
             │     ┌─────▼─────┐      │
             │     │  Get      │      │
             │     │  Config   │      │
             │     └─────┬─────┘      │
             │           │            │
             │     ┌─────▼─────┐      │
             │     │  Check    │      │
             │     │  Pending  │◄─────┤
             │     │  Cmd      │      │
             │     └─────┬─────┘      │
             │           │            │
             │     ┌─────▼─────┐      │
             │     │  Execute  │      │
             │     │  Cmd/Vlv  │      │
             │     └─────┬─────┘      │
             │           │            │
             │     ┌─────▼─────┐      │
             │     │  Post     │      │
             │     │  Reading  │      │
             │     └─────┬─────┘      │
             │           │            │
             │     ┌─────▼─────┐      │
             │     │  Deep     │      │
             └─────┤  Sleep    │      │
                   └───────────┘      │
                         │            │
                         ▼            │
                   (Bangun timer)─────┘
```

### Flow Chart Keputusan Valve

```
                    ┌──────────────┐
                    │ Baca Sensor  │
                    │ moisture%    │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │ Ada Pending  │
                    │ Command?     │
                    └──────┬───────┘
                      YES │    │ NO
                    ┌──────▼┐  │
                    │       │  │
               ┌────▼───┐  │  │
               │VALVE_ON│  │  │
               │?       │  │  │
               └────┬───┘  │  │
                YES │  NO  │  │
               ┌────▼──┐ ┌─▼──▼──────┐
               │Buka   │ │Tutup      │
               │Valve  │ │Valve      │
               │durasi │ └────┬──────┘
               └───┬───┘     │
                   │         │
              ┌────▼─────────▼──────┐
              │ PATCH status:       │
              │ "executed"          │
              └─────────┬───────────┘
                        │
                   ╔════▼════╗
                   ║ Mode    ║
                   ║ Auto?   ║
                   ╚════╤════╝
                   YES  │  NO (Manual)
              ┌─────────▼─────────┐
              │ moisture <        │  ┌──────────────┐
              │ threshold_dry?    │  │ Jangan apa-  │
              └─────────┬─────────┘  │ apa, valve   │
                   YES  │  NO       │ tetap CLOSED │
              ┌─────────▼┐          └──────────────┘
              │Buka Valve│
              │Otomatis  │
              │durasi    │
              └──────────┘
```

### Data Structures (C++)

```cpp
// === sensor.h ===
struct SensorReading {
  int raw;              // ADC 12-bit: 0-4095
  float percent;        // 0% (kering) - 100% (basah)
};

// === supabase_client.h ===
struct SystemConfig {
  String mode;          // "auto" | "manual"
  int thresholdDry;     // 0-100 (%)
  int thresholdWet;     // 0-100 (%)
  int valveDurationMs;  // milidetik (max 120000)
  int readIntervalSec;  // detik (default 1800)
  bool valid;           // dari cloud?
};

struct PendingCommand {
  long id;              // PK dari Supabase
  String command;       // "VALVE_ON" | "VALVE_OFF"
  int duration;         // detik
  bool valid;
};
```

### Memory Budget ESP32

| Komponen | RAM | Flash |
|----------|:---:|:-----:|
| Firmware ANDROMEDA | 47 KB (14%) | 943 KB (72%) |
| Sisa tersedia | **280 KB** | **368 KB** |
| Total ESP32 | 320 KB SRAM | 1.3 MB Flash |

### Library Dependencies (platformio.ini)

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
lib_deps =
    bblanchon/ArduinoJson @ ^6.21.3
```

### Konfigurasi Pin

| GPIO | Fungsi | Arah | Koneksi |
|:----:|--------|:----:|---------|
| 2 | LED Indikator | OUTPUT | Built-in ESP32 |
| 26 | Relay Control | OUTPUT | Relay Module IN |
| 34 | Sensor ADC | INPUT | Soil Sensor OUT |

---

## Backend Supabase

### Skema Database Lengkap

```sql
-- DATABASE ANDROMEDA — PostgreSQL via Supabase
-- Multi-device, no auth (pakai anon key)

-- 1. Tabel: devices — daftar petak
CREATE TABLE devices (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL UNIQUE,          -- "petak-01" s/d "petak-06"
  name TEXT NOT NULL,                       -- "Petak 1"
  location TEXT,                            -- "Lahan A" | "Lahan B"
  status TEXT NOT NULL DEFAULT 'active',    -- active | inactive | maintenance
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Tabel: sensor_readings — log data (write: ESP32, read: Flutter)
CREATE TABLE sensor_readings (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices(device_id),
  moisture INTEGER NOT NULL,                -- raw ADC
  moisture_percent REAL NOT NULL,           -- 0-100%
  valve_status TEXT NOT NULL DEFAULT 'OFF', -- ON | OFF
  battery_voltage REAL,                    -- tegangan aki (opsional)
  rssi INTEGER,                            -- kekuatan WiFi (opsional)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Tabel: pending_commands — antrian perintah (write: Flutter, read: ESP32)
CREATE TABLE pending_commands (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES devices(device_id),
  command TEXT NOT NULL,                    -- VALVE_ON | VALVE_OFF
  duration INTEGER DEFAULT 30,             -- detik (untuk VALVE_ON)
  status TEXT NOT NULL DEFAULT 'pending',   -- pending | executed | cancelled
  source TEXT NOT NULL DEFAULT 'android',   -- android | web | system
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  executed_at TIMESTAMPTZ                  -- diisi saat dieksekusi
);

-- 4. Tabel: system_config — konfigurasi per petak (write: Flutter, read: ESP32)
CREATE TABLE system_config (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  device_id TEXT NOT NULL UNIQUE REFERENCES devices(device_id),
  mode TEXT NOT NULL DEFAULT 'auto',         -- auto | manual
  threshold_dry INTEGER NOT NULL DEFAULT 30,  -- % (misal: <30% = kering)
  threshold_wet INTEGER NOT NULL DEFAULT 70,  -- % (misal: >70% = basah)
  valve_duration INTEGER NOT NULL DEFAULT 30, -- detik
  read_interval INTEGER NOT NULL DEFAULT 1800,-- detik (30 menit)
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by TEXT
);

-- 5. Indexes untuk performance
CREATE INDEX idx_sensor_readings_device_time 
  ON sensor_readings(device_id, created_at DESC);
CREATE INDEX idx_pending_commands_status 
  ON pending_commands(status);
CREATE INDEX idx_pending_commands_device_status 
  ON pending_commands(device_id, status);
```

### Hubungan Antar Tabel

```
devices
  │
  ├──< sensor_readings    (1 → banyak) — setiap device punya banyak log
  │
  ├──< pending_commands   (1 → banyak) — setiap device punya banyak perintah
  │
  └──= system_config      (1 → 1)      — setiap device punya 1 konfigurasi
```

### RLS Policies (No Auth — Public Access)

```sql
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sensor_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_commands ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_access_devices" 
  ON devices FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "public_access_sensor_readings" 
  ON sensor_readings FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "public_access_pending_commands" 
  ON pending_commands FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "public_access_system_config" 
  ON system_config FOR ALL TO anon USING (true) WITH CHECK (true);
```

### Realtime Publication

```sql
-- Aktifkan realtime untuk Flutter auto-sync
ALTER PUBLICATION supabase_realtime ADD TABLE sensor_readings;
ALTER PUBLICATION supabase_realtime ADD TABLE pending_commands;
ALTER PUBLICATION supabase_realtime ADD TABLE system_config;
```

### Data Seed (6 Petak)

```sql
INSERT INTO devices (device_id, name, location) VALUES
  ('petak-01', 'Petak 1 — Padi', 'Lahan A'),
  ('petak-02', 'Petak 2 — Padi', 'Lahan A'),
  ('petak-03', 'Petak 3 — Cabai', 'Lahan A'),
  ('petak-04', 'Petak 4 — Cabai', 'Lahan B'),
  ('petak-05', 'Petak 5 — Hortikultura', 'Lahan B'),
  ('petak-06', 'Petak 6 — Hortikultura', 'Lahan B');
```

### REST API Endpoints

| Method | Endpoint | Digunakan Oleh | Frekuensi |
|--------|----------|---------------|-----------|
| POST | `/rest/v1/sensor_readings` | ESP32 | Tiap 30 menit |
| GET | `/rest/v1/system_config?device_id=eq.X` | ESP32 | Tiap 30 menit |
| GET | `/rest/v1/pending_commands?device_id=eq.X&status=eq.pending` | ESP32 | Tiap 30 menit |
| PATCH | `/rest/v1/pending_commands?id=eq.X` | ESP32 | Setelah eksekusi |
| GET | `/rest/v1/sensor_readings?device_id=eq.X&order=created_at.desc&limit=100` | Flutter | Setiap buka app |
| GET | `/rest/v1/sensor_readings?device_id=eq.X&created_at=gte.YYYY-MM-DD` | Flutter | Grafik historis |
| POST | `/rest/v1/pending_commands` | Flutter | Saat user kirim perintah |
| PATCH | `/rest/v1/system_config?device_id=eq.X` | Flutter | Saat user ubah config |

---

## Aplikasi Flutter

### Struktur Project

```
mobile_app/
├── pubspec.yaml
├── lib/
│   ├── main.dart                    ← Entry point, inisialisasi Supabase
│   ├── app.dart                     ← MaterialApp, routing, tema
│   ├── config/
│   │   └── supabase_config.dart     ← URL + anon key
│   ├── models/
│   │   ├── device.dart              ← Model petak
│   │   ├── sensor_reading.dart      ← Model data sensor
│   │   └── system_config.dart       ← Model konfigurasi
│   ├── services/
│   │   └── supabase_service.dart    ← Wrapper Supabase API
│   ├── providers/
│   │   ├── devices_provider.dart    ← State management petak
│   │   └── dashboard_provider.dart   ← State management dashboard
│   ├── screens/
│   │   ├── splash_screen.dart       ← Splash + loading
│   │   ├── home_screen.dart         ← Daftar petak
│   │   ├── dashboard_screen.dart    ← Dashboard detail petak
│   │   └── settings_screen.dart     ← Pengaturan threshold
│   └── widgets/
│       ├── moisture_gauge.dart       ← Indikator kelembaban (melingkar)
│       ├── valve_control.dart        ← Tombol buka/tutup valve
│       ├── moisture_chart.dart       ← Grafik historis
│       ├── device_card.dart          ← Kartu petak di halaman utama
│       └── status_badge.dart         ← Lencana status (online/offline)
├── android/
├── ios/
└── test/
    ├── widget_test.dart
    └── services/
        └── supabase_service_test.dart
```

### Dependency (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.0.0      # Supabase SDK + Realtime
  fl_chart: ^0.68.0              # Grafik kelembaban
  provider: ^6.1.0               # State management
  intl: ^0.19.0                  # Format tanggal
  google_fonts: ^6.1.0           # Font (opsional)

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

### Fitur & Halaman Aplikasi

#### 1. Splash Screen

```
┌──────────────────────┐
│                      │
│    🚀 ANDROMEDA      │
│                      │
│  Irigasi Tetes       │
│  Otomatis Berbasis   │
│  IoT                 │
│                      │
│  ┌──────────────────┐│
│  │ ■■■■■■■■■■░░░░░░ ││ Loading...
│  └──────────────────┘│
│                      │
│  Teknologi Tepat     │
│  Guna untuk Petani   │
│                      │
└──────────────────────┘

→ Init Supabase
→ Cek koneksi internet
→ Redirect ke Home
```

#### 2. Home Screen — Daftar Petak

```
┌──────────────────────────────────────────┐
│ 🌾 ANDROMEDA                  🔔 ⚙️      │
├──────────────────────────────────────────┤
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 🌱 Petak 1 — Padi           🟢 ON   │ │
│ │ Kelembaban: 42%                      │ │
│ │ Valve: CLOSED       Status: Active   │ │
│ │ Terakhir: 2 menit lalu               │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 🌱 Petak 2 — Padi           🟢 ON   │ │
│ │ Kelembaban: 68%                      │ │
│ │ Valve: CLOSED       Status: Active   │ │
│ │ Terakhir: 5 menit lalu               │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 🌶️ Petak 3 — Cabai         🟢 ON   │ │
│ │ Kelembaban: 22% 🔴                  │ │
│ │ Valve: CLOSED       Status: Active   │ │
│ │ Terakhir: 1 menit lalu               │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ... dan 3 petak lainnya     ▶ Lihat │ │
│ └──────────────────────────────────────┘ │
│                                          │
└──────────────────────────────────────────┘
│
└── 📌 Navigasi Bawah:
    [🏠 Home]  [📊 Grafik]  [⚙️ Settings]
```

#### 3. Dashboard Screen — Detail Petak

```
┌──────────────────────────────────────────┐
│ ← 🌾 Petak 1 — Padi                       │
├──────────────────────────────────────────┤
│                                          │
│        ╔═══════════════╗                 │
│        ║    42%        ║                 │
│        ║  Lembab       ║                 │
│        ╚═══════════════╝                 │
│       Kelembaban Tanah                   │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ Status Valve: [⬜ CLOSED]  🟢 Aman  │ │
│ │ Mode: 🌙 Otomatis                    │ │
│ │ Siklus: 30 menit                     │ │
│ │ Terakhir: 2 menit lalu               │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 💧 Kontrol Valve                     │ │
│ │                                      │ │
│ │  [🔓 BUKA VALVE]    [🔒 TUTUP]      │ │
│ │                                      │ │
│ │ Durasi: [15s ▾] [30s ▾] [60s ▾]     │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 📈 Kelembaban — Hari Ini             │ │
│ │                                      │ │
│ │ 100% ┤                                │ │
│ │  80% ┤    ╱╲    ╱╲                    │ │
│ │  60% ┤ ╱╱  ╲╲╱╱  ╲╲                 │ │
│ │  40% ┤╱╱    ╲╲╱    ╲╲╱              │ │
│ │  20% ┤                               │ │
│ │   0% ┤─────────────────────────────  │ │
│ │      06  09  12  15  18  21  24      │ │
│ │                                      │ │
│ │ [📅 Hari Ini] [📅 7 Hari] [📅 Bulan]│ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ⚙️ Konfigurasi                       │ │
│ │                                      │ │
│ │ Threshold Kering : [30% ████░░░░]   │ │
│ │ Threshold Basah  : [70% ████████░░] │ │
│ │ Durasi Valve     : [30 dtk ████░░]  │ │
│ │ Interval Baca    : [30 mnt ████░░]  │ │
│ │                                      │ │
│ │ Mode: [🔘 Auto]  [○ Manual]         │ │
│ └──────────────────────────────────────┘ │
│                                          │
└──────────────────────────────────────────┘
```

#### 4. Settings Screen

```
┌──────────────────────────────────────────┐
│ ← ⚙️ Pengaturan                          │
├──────────────────────────────────────────┤
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 🌐 Koneksi                           │ │
│ │                                      │ │
│ │ Status: 🟢 Terhubung                 │ │
│ │ Server: Supabase                     │ │
│ │ Sinyal: 📶 4G (RSSI: -65dBm)        │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 🔔 Notifikasi                        │ │
│ │                                      │ │
│ │ [✅] Kelembaban kritis               │ │
│ │ [✅] Valve error                    │ │
│ │ [  ] Mode penyiraman                  │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ 📤 Ekspor Data                       │ │
│ │                                      │ │
│ │ CSV harian  CSV mingguan  CSV bulanan│ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │ ℹ️ Tentang                           │ │
│ │                                      │ │
│ │ ANDROMEDA v1.0                       │ │
│ │ PDB Desa Merayan                     │ │
│ │ MIT License                          │ │
│ └──────────────────────────────────────┘ │
│                                          │
└──────────────────────────────────────────┘
```

### State Management Flow

```
                ┌──────────────┐
                │   Supabase   │
                │  (Cloud DB)  │
                └──────┬───────┘
                       │ Realtime (WebSocket)
          ┌────────────┴────────────┐
          │                         │
    ┌─────▼─────┐           ┌──────▼──────┐
    │  Provider  │           │  Supabase   │
    │ (State)    │           │  Client     │
    │            │           │  (Direct)   │
    │ devices    │           │             │
    │ dashboard  │           │ stream()    │
    └─────┬─────┘           │ subscribe() │
          │                  └─────────────┘
          │
    ┌─────▼─────┐
    │   UI      │
    │ (Widget)  │
    │           │
    │ Consumer  │
    └───────────┘
```

### Widget Tree Utama

```
MaterialApp
 └─ StreamBuilder (auth / anon)
    └─ Navigator
       ├─ SplashScreen
       ├─ HomeScreen
       │   └─ ListView
       │       └─ DeviceCard (×6)
       ├─ DashboardScreen
       │   ├─ MoistureGauge
       │   ├─ ValveControl
       │   ├─ MoistureChart
       │   └─ ConfigPanel
       └─ SettingsScreen
```

### Algoritma Bisnis di Aplikasi

```dart
// 1. Kirim perintah ke ESP32 via Supabase
Future<void> sendValveCommand(String deviceId, String command, int duration) async {
  await supabase.from('pending_commands').insert({
    'device_id': deviceId,
    'command': command,
    'duration': duration,
    'status': 'pending',
    'source': 'android',
  });
}

// 2. Update konfigurasi petak
Future<void> updateConfig(String deviceId, SystemConfig config) async {
  await supabase.from('system_config').update({
    'mode': config.mode,
    'threshold_dry': config.thresholdDry,
    'threshold_wet': config.thresholdWet,
    'valve_duration': config.valveDuration,
    'read_interval': config.readInterval,
    'updated_by': 'android',
  }).eq('device_id', deviceId);
}

// 3. Ambil data grafik historis
Stream<List<SensorReading>> getHistoryStream(String deviceId, {required int days}) {
  final since = DateTime.now().subtract(Duration(days: days)).toIso8601String();
  return supabase
    .from('sensor_readings')
    .stream(primaryKey: ['id'])
    .eq('device_id', deviceId)
    .gte('created_at', since)
    .order('created_at', ascending: true);
}
```

### Theme Aplikasi

```dart
// Warna khas ANDROMEDA
// Hijau alam, biru air, oranye matahari
ThemeData(
  primarySwatch: Colors.green,
  colorScheme: ColorScheme(
    primary: Color(0xFF2E7D32),       // Hijau gelap (header)
    secondary: Color(0xFF1565C0),     // Biru (air)
    tertiary: Color(0xFFE65100),      // Oranye (matahari) — alert
    surface: Color(0xFFF5F5F5),       // Background kartu
    // ...
  ),
  fontFamily: 'GoogleFonts.plusJakartaSans',
  cardTheme: CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: 12),
  ),
);
```

---

## Sistem Daya & Internet

### Rangkaian Power Distribution

```
                    ┌─────────────────────────┐
                    │   Solar Panel 300Wp     │
                    │   Vmp: 36V, Imp: 8.3A   │
                    │   Ukuran: ~2m × 1m      │
                    └───────────┬─────────────┘
                                │ Kabel PV 4mm² (10m)
                    ┌───────────▼─────────────┐
                    │   Sungold SCC 20A       │
                    │   PWM Solar Charge      │
                    │   Controller            │
                    │                         │
                    │   Battery: 12V          │
                    │   Load:   12V           │
                    │   Max:    20A/240W      │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │   MCB 1P 6A             │
                    │   (pengaman hubung       │
                    │    singkat)             │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │   Aki Kering 100Ah      │
                    │   Yuasa NS70 / Setara   │
                    │   12V DC                │
                    │   Kapasitas: 1200Wh     │
                    └───────────┬─────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          │                     │                     │
          ▼                     ▼                     ▼
   ┌────────────┐      ┌──────────────┐      ┌──────────────┐
   │ Step-down  │      │ Step-down    │      │ 12V Langsung  │
   │ 12V → 5V   │      │ 12V → 5V     │      │              │
   │ 2A         │      │ (x6 unit)    │      │              │
   │            │      │ 12V→5V/2A    │      ├── Solenoid   │
   │ Huawei     │      │              │      │   Valve      │
   │ B535       │      │ ESP32 +      │      │   (6 unit,   │
   │ Router     │      │ Relay Module │      │   bergantian)│
   └────────────┘      │ (×6)         │      │              │
                       └──────────────┘      └──────────────┘
```

### Perhitungan Daya Detail

#### Beban per Komponen

| Komponen | Tegangan | Arus | Daya | Jumlah | Total Daya |
|----------|:-------:|:----:|:----:|:-----:|:----------:|
| ESP32 (deep sleep) | 5V | 5 µA | 0,025 mW | 6 | 0,15 mW |
| ESP32 (aktif) | 5V | 80 mA | 400 mW | 1 (bergantian) | 400 mW |
| Relay (aktif) | 5V | 70 mA | 350 mW | 1 | 350 mW |
| Solenoid Valve | 12V | 500 mA | 6.000 mW | 1 | 6.000 mW |
| Router B535 (idle) | 12V | 300 mA | 3.600 mW | 1 | 3.600 mW |
| Router B535 (max) | 12V | 1.000 mA | 12.000 mW | 1 | 12.000 mW |

#### Konsumsi per Siklus (30 menit)

| Fase | Daya | Durasi | Energi |
|------|:----:|:------:|:------:|
| Deep sleep (6 ESP) | 0,15 mW | 29:57 | 0,075 mWh |
| WiFi + Sensor + HTTP (1 ESP) | 400 mW | 3 detik | 0,33 mWh |
| Router B535 (idle) | 3.600 mW | 30 menit | 1.800 mWh |
| **Total per 30 menit** | | | **~1.800 mWh** |

#### Per Siklus dengan Valve (Sekali Siram)

| Fase | Daya | Durasi | Energi |
|------|:----:|:------:|:------:|
| Base siklus | ~1.800 mW | 30 menit | 1.800 mWh |
| Valve ON (1 valve) | 6.000 mW | 30 detik | 50 mWh |
| **Total per siklus siram** | | | **~1.850 mWh** |

#### Konsumsi Harian

| Skenario | Per Siklus | Siklus/Hari | Energi/Hari |
|----------|:----------:|:-----------:|:-----------:|
| Tanpa siram | 1.800 mWh | 48 | **86,4 Wh** |
| Dengan siram (6×/hari) | 1.850 mWh | 48 | **88,8 Wh** |

#### Daya Tahan Aki

| Skenario | Konsumsi/Hari | Aki 100Ah (1.200 Wh) | + Panel 300Wp |
|----------|:-------------:|:--------------------:|:-------------:|
| Tanpa siram | 86,4 Wh | **~13,8 hari** | 🔋 **Terisi penuh** |
| Dengan siram | 88,8 Wh | **~13,5 hari** | 🔋 **Terisi penuh** |
| Beban maksimal | 360 Wh (router max terus) | **~3,3 hari** | **Terisi penuh** |

> **Panel 300Wp** dengan rata-rata 4-5 jam puncak matahari → **1.200-1.500 Wh/hari**  
> Ini **jauh lebih besar** dari konsumsi harian (86-360 Wh) — **sistem surplus besar** ✅

### Rangkaian Internet

```
                    ┌─────────────────────┐
                    │   Menara BTS 4G     │
                    │   (Operator: XL/AXIS│
                    │    atau Telkomsel)  │
                    └─────────┬───────────┘
                              │ Sinyal 4G LTE
                    ┌─────────▼───────────┐
                    │ Antena Outdoor 4G   │
                    │ 5-10 dBi            │
                    │ Dipasang di tiang   │
                    │ 3-5 meter (jika     │
                    │ sinyal lemah)       │
                    └─────────┬───────────┘
                              │ Kabel pigtail SMA
                    ┌─────────▼───────────┐
                    │ Huawei B535-932     │
                    │ 4G LTE Router       │
                    │ WiFi 2.4 GHz        │
                    │ 300 Mbps            │
                    │                     │
                    │ IP: 192.168.8.1     │
                    │ DHCP: 192.168.8.100-│
                    │        192.168.8.200│
                    └─────────┬───────────┘
                              │ WiFi
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
   ┌───────────┐      ┌───────────┐       ┌───────────┐
   │ ESP32     │      │ ESP32     │       │ ESP32     │
   │ Petak 1   │      │ Petak 2   │  ...  │ Petak 6   │
   │ WiFi sta  │      │ WiFi sta  │       │ WiFi sta  │
   └───────────┘      └───────────┘       └───────────┘
```

#### Konfigurasi Router Huawei B535

| Parameter | Setting |
|-----------|---------|
| SSID | `ANDROMEDA-Desa` |
| Password | `desamerayan123` |
| Mode | 2.4 GHz only (jangkauan lebih jauh) |
| DHCP | Enabled, pool 192.168.8.100-200 |
| Keamanan | WPA2-PSK |
| Paket Data | Rp 15.000/bulan (1-5GB cukup) |

---

## Instalasi & Wiring Lapangan

### Layout Lahan

```
                         LAHAN A                 LAHAN B
   ┌─────────────────────────────────────────────────────────┐
   │                                                         │
   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
   │  │   Petak 1    │  │   Petak 2    │  │   Petak 3    │  │
   │  │   Padi       │  │   Padi       │  │   Cabai      │  │
   │  │   1m × 7m    │  │   1m × 7m    │  │   1m × 7m    │  │
   │  │              │  │              │  │              │  │
   │  │ [☀️ Panel]  │  │              │  │              │  │
   │  │ [📦 Box]    │  │              │  │              │  │
   │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
   │         │                 │                 │          │
   │         └────────┬────────┴────────┬────────┘          │
   │                  │                 │                    │
   │          ┌───────▼─────────────────▼───────┐           │
   │          │        JALUR AIR UTAMA          │           │
   │          │   Selang PE 16mm dari Tandon    │           │
   │          └─────────────────────────────────┘           │
   │                                                         │
   │                    ┌─────────────┐                      │
   │                    │   TANDON    │                      │
   │                    │     AIR     │                      │
   │                    │   (SUDAH    │                      │
   │                    │    ADA)     │                      │
   │                    └──────┬──────┘                      │
   │                           │                             │
   │                    ┌──────▼──────┐                      │
   │                    │  Solenoid   │                      │
   │                    │  Valve 12V  │                      │
   │                    │  NC (utama) │                      │
   │                    └──────┬──────┘                      │
   │                           │                             │
   │                    ┌──────▼──────┐                      │
   │                    │  Filter Air │                      │
   │                    └─────────────┘                      │
   │                                                         │
   │    🏠 [Rumah Petani/Panel Center]                       │
   │       ┌─────────────────────────────────┐               │
   │       │ Aki + SCC + MCB + Router B535  │               │
   │       │ + Step-down 5V (×6)            │               │
   │       └─────────────────────────────────┘               │
   │                                                         │
   └─────────────────────────────────────────────────────────┘
```

### Tahapan Instalasi

#### Fase 1 — Persiapan (1 Hari)

| # | Kegiatan | Durasi | Alat |
|:-:|----------|:------:|------|
| 1.1 | Survei lokasi & ukur jarak | 2 jam | Meteran, GPS HP |
| 1.2 | Tentukan posisi panel center & tandon | 1 jam | - |
| 1.3 | Ukur panjang jalur kabel & selang | 2 jam | Meteran |
| 1.4 | Beli semua komponen | 3 jam | Motor/Mobil |

#### Fase 2 — Perakitan Panel Center (1 Hari)

| # | Kegiatan | Durasi | Detail |
|:-:|----------|:------:|--------|
| 2.1 | Pasang MCB di jalur aki | 30 menit | MCB 1P 6A |
| 2.2 | Hubungkan SCC ke aki | 20 menit | + ke +, - ke - |
| 2.3 | Pasang step-down 12V→5V (×6) | 1 jam | Output 5V/2A |
| 2.4 | Rakit terminal block | 30 menit | Label tiap petak |
| 2.5 | Pasang router B535 | 15 menit | Colok 12V |
| 2.6 | Uji tegangan semua output | 30 menit | Multimeter |

#### Fase 3 — Perakitan ESP32 Box (1 Hari)

| # | Kegiatan | Durasi | Detail |
|:-:|----------|:------:|--------|
| 3.1 | Solder pin header ke ESP32 | 30 menit | Hati-hati pinout |
| 3.2 | Pasang relay module di box | 15 menit | Sekrup/lem |
| 3.3 | Pasang terminal block | 15 menit | 12 pin |
| 3.4 | Pasang LED indikator + resistor | 20 menit | Biru = power, merah = error |
| 3.5 | Pasang kapasitor 100nF | 5 menit | GPIO34 ke GND |
| 3.6 | Wiring internal | 30 menit | Ikuti diagram wiring |
| 3.7 | Uji coba dengan kabel pendek | 1 jam | Flash firmware, test |
| 3.8 | Ulangi untuk 6 box | 6 × 1 jam | Sambil chating 🤣 |

#### Fase 4 — Instalasi Lapangan (2 Hari)

| # | Kegiatan | Durasi | Detail |
|:-:|----------|:------:|--------|
| 4.1 | Gali alur kabel sensor (20m × 6) | 3 jam | Kedalaman 10cm |
| 4.2 | Tarik kabel UTP Cat5e | 2 jam | Dari box ke tiap petak |
| 4.3 | Pasang sensor di tanah | 1 jam | Vertikal, 5-7cm dalam |
| 4.4 | Pasang selang drip | 2 jam | Sepanjang bedengan |
| 4.5 | Pasang solenoid valve | 30 menit | Di dekat tandon |
| 4.6 | Koneksi solenoid ke relay | 30 menit | Kabel NYMHY 2×1.5mm |
| 4.7 | Tes aliran air | 1 jam | Buka valve manual |
| 4.8 | Kalibrasi sensor awal | 2 jam | Baca basah & kering |

#### Fase 5 — Solar Panel (1 Hari)

| # | Kegiatan | Durasi | Detail |
|:-:|----------|:------:|--------|
| 5.1 | Pasang mounting panel | 2 jam | Tiang besi/hollow |
| 5.2 | Pasang panel 300Wp di atap/tiang | 1 jam | 2 orang |
| 5.3 | Tarik kabel PV 4mm² ke SCC | 30 menit | MC4 connector |
| 5.4 | Uji pengisian aki | 1 jam | Ukur tegangan siang hari |

### Checklist Instalasi

```
☐ Semua komponen sudah dibeli dan diinventarisir
☐ ESP32 sudah di-flash firmware sesuai petak
☐ Panel center sudah terangkai lengkap
☐ Tegangan output step-down: 5V ±0.2V
☐ Kabel sensor sudah ditarik tanpa sambungan
☐ Semua koneksi terminal block sudah kencang
☐ Solenoid valve terpasang dengan arah aliran benar (panah)
☐ Sensor tertanam vertikal 5-7cm, tidak menyentuh batu
☐ Selang drip tidak bocor di sambungan
☐ Router B535 terhubung ke 4G
☐ Aki terisi penuh (12.6V+)
☐ Solar panel menghadap utara/selatan (tergantung lokasi)
☐ SCC menampilkan charging (lampu hijau)
☐ ESP32 connect ke WiFi
☐ Data masuk ke Supabase
☐ Aplikasi Flutter menampilkan data realtime
```

---

## Kalibrasi & Threshold Tanaman

### Prosedur Kalibrasi Sensor

```
Langkah 1: Basah
─────────────
1. Siram tanah sampai benar-benar jenuh (air menggenang)
2. Tunggu 5 menit agar air meresap
3. Baca nilai ADC → catat sebagai BASAH_REF
   Contoh: analogRead = 1500

Langkah 2: Kering
───────────────
1. Biarkan tanah mengering 3-5 hari (tergantung cuaca)
2. Jangan disiram selama periode ini
3. Baca nilai ADC tiap 12 jam
4. Saat tanaman mulai layu → catat sebagai KERING_REF
   Contoh: analogRead = 2700

Langkah 3: Update kode
─────────────────────
Di sensor.cpp:
  float percent = 100.0f - ((raw - 1500.0f) / (2700.0f - 1500.0f)) * 100.0f;
                                  ↑ BASAH_REF      ↑ KERING_REF
```

### Threshold Default per Tanaman

| Tanaman | Threshold Kering | Threshold Basah | Durasi Valve | Catatan |
|---------|:----------------:|:---------------:|:------------:|---------|
| **Padi** | 20% | 80% | 45 detik | Butuh air terus |
| **Cabai** | 30% | 60% | 30 detik | Sensitif over-water |
| **Tomat** | 35% | 65% | 25 detik | Sedang |
| **Terong** | 30% | 70% | 35 detik | Toleran |
| **Kangkung** | 25% | 75% | 20 detik | Cepat panen |
| **Bayam** | 20% | 70% | 20 detik | Cepat panen |

### Frekuensi Penyiraman Ideal

| Tanaman | Frekuensi | Volume per Siram | Waktu Terbaik |
|---------|:---------:|:----------------:|:-------------:|
| Padi | 2-3×/hari | 2-3 liter/tanaman | Pagi & sore |
| Cabai | 1-2×/hari | 1-2 liter/tanaman | Pagi |
| Tomat | 1-2×/hari | 1-2 liter/tanaman | Pagi |
| Terong | 1×/hari | 1-2 liter/tanaman | Pagi |
| Kangkung | 2×/hari | 0.5 liter/tanaman | Pagi & sore |
| Bayam | 2×/hari | 0.5 liter/tanaman | Pagi & sore |

---

## Pengujian & Validasi

### Skenario Uji Fungsional

| # | Skenario | Prosedur | Hasil Diharapkan |
|:-:|----------|----------|------------------|
| **FW-1** | ESP32 boot & WiFi | Flash firmware, lihat serial | "Connected IP: 192.168.x.x" |
| **FW-2** | Baca sensor | Letakkan sensor di air & udara kering | Nilai ADC berbeda signifikan |
| **FW-3** | Kirim data | POST ke Supabase via ESP32 | Data muncul di Table Editor |
| **FW-4** | Valve ON manual | Kirim perintah VALVE_ON | Valve terbuka, air mengalir |
| **FW-5** | Valve OFF manual | Kirim perintah VALVE_OFF | Valve tertutup |
| **FW-6** | Mode auto kering | Biarkan tanah kering < threshold | Valve otomatis terbuka |
| **FW-7** | Mode auto basah | Siram tanah sampai basah | Valve tetap tertutup |
| **FW-8** | Deep sleep | Ukur arus setelah 5 detik | ~5 µA |
| **FW-9** | WiFi fail | Matikan router | ESP32 langsung deep sleep |
| **FW-10** | Safety valve | Cabut power ESP32 saat valve ON | Valve NC → otomatis tertutup |

### Skenario Uji Aplikasi

| # | Skenario | Prosedur | Hasil Diharapkan |
|:-:|----------|----------|------------------|
| **APP-1** | Buka aplikasi | Tap ikon ANDROMEDA | Loading → Home screen |
| **APP-2** | Lihat realtime | Tunggu 30 detik | Data sensor muncul & update |
| **APP-3** | Buka valve | Tap "BUKA VALVE", pilih durasi | Valve terbuka, status berubah |
| **APP-4** | Tutup valve | Tap "TUTUP VALVE" | Valve tertutup, status berubah |
| **APP-5** | Ubah threshold | Geser slider threshold | Config ter-update di Supabase |
| **APP-6** | Ganti mode | Pilih "Manual" mode | Valve tidak otomatis lagi |
| **APP-7** | Grafik harian | Buka petak → tab grafik | Chart muncul dengan data |
| **APP-8** | Multi petak | Swipe/list antar petak | Data per petak benar |

### Skenario Uji Daya

| # | Skenario | Prosedur | Hasil Diharapkan |
|:-:|----------|----------|------------------|
| **PWR-1** | Deep sleep | Ukur arus ESP32 tidur | ~5 µA |
| **PWR-2** | Aktif + WiFi | Ukur arus saat HTTP | ~80 mA |
| **PWR-3** | Valve ON | Ukur arus solenoid | ~500 mA (12V) |
| **PWR-4** | Pengisian solar | Ukur arus SCC siang hari | 5-10A masuk ke aki |
| **PWR-5** | Aki malam | Ukur tegangan aki subuh | >12.0V (tidak drop) |
| **PWR-6** | Aki hujan 3 hari | Simulasi tanpa panel 3 hari | Tegangan >11.5V |

### Uji Coba Lapangan — Protokol

```
HARI KE-1: Instalasi & Kalibrasi
  ☐ Pasang semua hardware
  ☐ Kalibrasi sensor basah
  ☐ Data masuk ke Supabase ✅

HARI KE-2: Uji Coba Manual
  ☐ Buka valve 30 detik → air mengalir?
  ☐ Tutup valve → berhenti?
  ☐ Aplikasi kontrol valve berfungsi?

HARI KE-3 s/d KE-5: Uji Coba Otomatis
  ☐ Biarkan tanah mengering
  ☐ ESP32 otomatis buka valve saat kering? ⏰
  ☐ Grafik kelembaban terekam di aplikasi?

HARI KE-6 s/d KE-14: Uji Coba Full (7 Hari)
  ☐ Sistem berjalan 24/7 tanpa intervensi
  ☐ Aki tidak drop (monitor tiap pagi)
  ☐ Data masuk konsisten tiap 30 menit
  ☐ Tidak ada kegagalan WiFi

HARI KE-15: Evaluasi & Laporan
  ☐ Hitung total penyiraman
  ☐ Bandingkan dengan manual (hemat berapa liter?)
  ☐ Catat kendala & perbaikan
  ☐ Wawancara petani (feedback)
```

---

## Roadmap & Timeline

### Timeline Proyek (8 Minggu)

```
MINGGU 1-2: PERSIAPAN
──────────────────────────────────────────────────
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░
Belanja komponen, rakit panel center, rakit ESP32 box

MINGGU 3-4: INSTALASI
──────────────────────────────────────────────────
░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░
Instalasi lapangan, tarik kabel & selang, pasang solar

MINGGU 5: KALIBRASI
──────────────────────────────────────────────────
░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░
Kalibrasi sensor, set threshold per tanaman

MINGGU 6-7: UJI COBA
──────────────────────────────────────────────────
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
Uji coba 14 hari penuh, monitoring, catat data

MINGGU 8: EVALUASI & LAPORAN
──────────────────────────────────────────────────
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓
Evaluasi, laporan akhir, presentasi ke desa
```

### Milestone

| Milestone | Target Tanggal | Status |
|-----------|:--------------:|:------:|
| ✅ Proposal teknis disetujui | Selesai | ✅ |
| ✅ ESP32 firmware selesai | Selesai | ✅ |
| ✅ Backend Supabase siap | Selesai | ✅ |
| ✅ Aplikasi Flutter MVP | Selesai | ✅ |
| 🔄 Komponen hardware dibeli | Minggu 1 | ⏳ |
| 🔄 Panel center & box dirakit | Minggu 2 | ⏳ |
| 🔄 Instalasi lapangan | Minggu 3-4 | ⏳ |
| 🔄 Kalibrasi sensor | Minggu 5 | ⏳ |
| 🔄 Uji coba 14 hari | Minggu 6-7 | ⏳ |
| 🔄 Laporan akhir | Minggu 8 | ⏳ |

### Pembagian Tugas

| Peran | Nama | Tugas |
|-------|------|-------|
| **Ketua/Pengembang** | Farrel Ghozy | Koordinasi, firmware, backend, aplikasi |
| **Teknisi Hardware** | (Cari asisten) | Rakit hardware, instalasi lapangan |
| **Petani Mitra** | (Nama petani) | Pendamping lapangan, operasional harian |
| **Dosen Pembimbing** | (Nama dosen) | Arahan akademik, evaluasi |

---

## Anggaran Biaya

### Detail Biaya Lengkap

| No | Item | Satuan | Qty | Harga Satuan | Subtotal |
|:--:|------|:-----:|:---:|:------------:|:--------:|
| | **PERANGKAT KERAS (6 PETAK)** | | | | |
| 1 | ESP32 DevKit 30 Pin | unit | 6 | Rp 65.000 | Rp 390.000 |
| 2 | Capacitive Soil Sensor v1.2 | unit | 6 | Rp 35.000 | Rp 210.000 |
| 3 | Relay Module 1ch 5V Optocoupler | unit | 6 | Rp 12.000 | Rp 72.000 |
| 4 | Solenoid Valve 12V NC 1/2" | unit | 6 | Rp 50.000 | Rp 300.000 |
| 5 | Step-down 12V→5V/2A LM2596 | unit | 6 | Rp 18.000 | Rp 108.000 |
| 6 | LED + Resistor + Kapasitor | set | 6 | Rp 5.000 | Rp 30.000 |
| 7 | Project Box 200×150×100mm | unit | 6 | Rp 45.000 | Rp 270.000 |
| 8 | Terminal Block 12 pin | unit | 12 | Rp 6.000 | Rp 72.000 |
| 9 | Kabel UTP Cat5e (sensor) | meter | 120 | Rp 6.000 | Rp 720.000 |
| 10 | Kabel NYMHY 2×1.5mm (power) | meter | 60 | Rp 4.000 | Rp 240.000 |
| 11 | Kabel Jumper + Pelengkap | set | 6 | Rp 15.000 | Rp 90.000 |
| | | | | | |
| | **IRIGASI (6 PETAK)** | | | | |
| 12 | Selang PE Drip 16mm | meter | 120 | Rp 2.500 | Rp 300.000 |
| 13 | Dripper/Emitter Irigasi | pcs | 60 | Rp 1.500 | Rp 90.000 |
| 14 | Fitting Selang (Tee, Elbow) | set | 6 | Rp 40.000 | Rp 240.000 |
| | | | | | |
| | **INVESTASI BERSAMA** | | | | |
| 15 | Huawei B535-932 4G LTE Router | unit | 1 | Rp 450.000 | Rp 450.000 |
| 16 | Aki Kering 100Ah NS70 | unit | 1 | Rp 1.100.000 | Rp 1.100.000 |
| 17 | Solar Panel 300Wp Polycrystalline | unit | 1 | Rp 1.200.000 | Rp 1.200.000 |
| 18 | Solar Charge Controller 20A PWM | unit | 1 | Rp 125.000 | Rp 125.000 |
| 19 | MCB 1P 6A + Box Panel | unit | 1 | Rp 50.000 | Rp 50.000 |
| 20 | Antena Outdoor 4G 10dBi | unit | 1 | Rp 150.000 | Rp 150.000 |
| 21 | Kabel Power NYMHY 2×2.5mm | meter | 30 | Rp 5.000 | Rp 150.000 |
| 22 | Kabel Solar PV 4mm² + MC4 | set | 1 | Rp 150.000 | Rp 150.000 |
| 23 | Perlengkapan (ties, duct tape, dll) | set | 1 | Rp 100.000 | Rp 100.000 |
| | | | | | |
| | **BIAYA OPERASIONAL BULANAN** | | | | |
| 24 | Paket Data 4G (XL/Axis/Tsel) | bulan | 1 | Rp 15.000 | Rp 15.000 |
| | | | | | |
| | **TOTAL 6 PETAK + INVESTASI** | | | | **Rp 6.442.000** |
| | **BIAYA PER BULAN** | | | | **Rp 15.000** |

### Opsi Penghematan

| Komponen | Harga Normal | Alternatif Murah | Hemat |
|----------|:-----------:|:----------------:|:-----:|
| ESP32 DevKit | Rp 65rb | ESP32 pada China/Tokopedia | Rp 45rb |
| Kabel UTP Cat5e | Rp 6rb/m | Kabel telepon antik (2 pair) | Rp 3rb/m |
| Dripper Irigasi | Rp 1.500/pcs | Buat dari selang infus bekas | Rp 0 |
| Aki 100Ah | Rp 1.1jt | Aki bekas forklift (rebutan) | Rp 400rb |
| Panel 300Wp | Rp 1.2jt | Panel 200Wp bekas | Rp 600rb |

---

## Daftar Risiko & Mitigasi

| Risiko | Probabilitas | Dampak | Mitigasi |
|--------|:------------:|:------:|----------|
| **Solenoid valve rusak** | Rendah | Tinggi | Punya 1 spare valve |
| **ESP32 rusak** | Rendah | Tinggi | Punya 1 spare ESP32 + firmware backup |
| **Aki tekor** (saat hujan >7 hari) | Sedang | Tinggi | Panel 300Wp surplus besar; alternatif: bawa aki cadangan |
| **Router B535 mati** | Rendah | Sangat Tinggi | Punya modem USB E3372 cadangan |
| **Kabel sensor putus** (di lapangan) | Sedang | Sedang | Tarik kabel di pipa PVC 1/2" |
| **Sensor korosi** (meski kapasitif) | Rendah | Sedang | Lapisi dengan selotip teflon + heat shrink |
| **Sinyal 4G lemah** | Sedang | Sedang | Antena outdoor 10dBi + posisi tinggi |
| **Paket data habis** | Sedang | Rendah | Auto-topup pulsa atau kuota 5GB/bulan |
| **Selang bocor** | Sedang | Rendah | Cek fitting rutin, bawa spare fitting |
| **Semut/serangga di box** | Tinggi | Sedang | Box kedap + beri kapur anti serangga |
| **Banjir lahan** | Rendah | Tinggi | Letakkan box di posisi lebih tinggi (tiang) |
| **Pencurian panel/kabel** | Sedang | Tinggi | Kunci box + panel; sosialisasi ke warga |

### Rencana Kontinjensi

```
JIKA SOLENOID VALVE RUSAK:
  1. Matikan power valve (cabut kabel)
  2. Gunakan kran manual di tandon untuk sementara
  3. Ganti valve dengan spare
  4. Test setelah diganti

JIKA ESP32 RUSAK:
  1. Ambil spare ESP32 yang sudah di-flash
  2. Colok ke box yang sama
  3. Test koneksi WiFi
  4. Selesai (5 menit)

JIKA WIFI/4G DOWN:
  1. Cek lampu indikator router
  2. Restart router (cabut power 10 detik)
  3. Kalau masih mati → pakai HP hotspot sementara
  4. ESP32 tetap jalan dengan config terakhir (mode otomatis terus jalan!)

JIKA AKI HABIS (HARI HUJAN):
  1. Panel 300Wp biasanya cukup meski mendung
  2. Jika benar-benar habis → bawa aki ke rumah, charge pakai listrik PLN
  3. Pasang aki cadangan kalau ada
  4. Sistem tetap bisa di-charge dalam 3-4 jam setelah panel kena matahari
```

---

## Catatan Akhir

### Keunggulan ANDROMEDA

| Aspek | ANDROMEDA | Sistem Komersial | Manual |
|-------|:----------:|:----------------:|:------:|
| Biaya hardware | **~Rp 6,4jt** (6 petak) | Rp 15-30jt | Rp 0 |
| Biaya per bulan | **Rp 15.000** | Rp 150-300rb | Rp 0 |
| Monitoring HP | ✅ **Ya** | ✅ Ya | ❌ |
| Off-grid | ✅ **Ya** | ⚠️ Sebagian | ✅ Ya |
| Otomatis | ✅ **Ya** | ✅ Ya | ❌ |
| Open source | ✅ **MIT** | ❌ Proprietary | N/A |
| Dikembangkan desa lain | ✅ **Bisa** | ❌ Lisensi | ❌ |

### Filosofi Desain

> **"Sesederhana mungkin, setangguh mungkin."**

1. Kalau bisa pakai gravity, kenapa pakai pompa?
2. Kalau bisa deep sleep, kenapa selalu aktif?
3. Kalau bisa NC valve (fail-safe), kenapa NO?
4. Kalau bisa Rp 15rb/bulan, kenapa Rp 150rb?
5. Kalau bisa open source, kenapa proprietary?

### Fitur Lanjutan (Versi 2.0 — Masa Depan)

```
☐ Prediksi penyiraman berbasis cuaca (BMKG API)
☐ Multiple sensor per petak (suhu, pH tanah)
☐ Dashboard web untuk dinas/penyuluh
☐ Ekspor data ke CSV/Excel untuk laporan
☐ Kalender tanam otomatis
☐ Notifikasi Telegram (selain aplikasi)
☐ Integrasi dengan irigasi desa yang lebih besar
☐ Mode pembelajaran otomatis (AI threshold)
☐ Barcode/QR untuk tiap petak
☐ Multi-bahasa (Indonesia/Inggris/Jawa)
```

---

> 🌾 *ANDROMEDA — Dari petani, oleh petani, untuk petani.*  
> *Teknologi tepat guna untuk kemandirian pangan Indonesia.*  
>  
> **📧** farrelafif05@gmail.com  
> **🐙** github.com/FarrelGhozy/andromeda  
> **📱** +62-xxx-xxxx-xxxx
