# 🧠 Arsitektur ESP32 — ANDROMEDA

**ANDROMEDA** (Android Routine Monitoring Electronic Drip Automation)  
Sistem Irigasi Tetes Otomatis Berbasis IoT  
Program PDB (Program Desa Binaan) — **Desa Merayan**

---

## 📋 Daftar Isi

1. [Gambaran Umum](#-gambaran-umum)
2. [Diagram Arsitektur ESP32](#-diagram-arsitektur-esp32)
3. [State Machine Firmware](#-state-machine-firmware)
4. [Struktur Kode](#-struktur-kode)
5. [Konfigurasi Multi-Petak](#-konfigurasi-multi-petak)
6. [Pin Mapping & Wiring](#-pin-mapping--wiring)
7. [Protokol Komunikasi Supabase](#-protokol-komunikasi-supabase)
8. [Manajemen Daya & Deep Sleep](#-manajemen-daya--deep-sleep)
9. [Kalibrasi Sensor Kelembaban](#-kalibrasi-sensor-kelembaban)
10. [Safety & Fail-Safe](#-safety--fail-safe)
11. [PlatformIO Build System](#-platformio-build-system)
12. [Troubleshooting](#-troubleshooting)

---

## 🎯 Gambaran Umum

ESP32 bertindak sebagai **otak utama** sistem ANDROMEDA. Tiap petak (bedengan) memiliki **satu unit ESP32** yang bertugas:

| Tugas | Metadata |
|-------|----------|
| Baca sensor kelembaban tanah | Tiap 30 menit (default) |
| Kirim data ke Supabase | HTTP POST via WiFi |
| Ambil konfigurasi dari cloud | HTTP GET `system_config` |
| Periksa perintah dari aplikasi | HTTP GET `pending_commands` |
| Kontrol solenoid valve | Via relay module 1 channel |
| Deep sleep di sela siklus | ~5 µA saat tidur |

Total ada **6 unit ESP32** untuk 6 petak (3 di Lahan A, 3 di Lahan B).

---

## 🏗️ Diagram Arsitektur ESP32

```
┌──────────────────────────────────────────────────────────────────┐
│                        ESP32 DevKit                              │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    FIRMWARE LAYER                         │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │               main.cpp (siklus)                   │  │   │
│  │  └──────┬──────────┬──────────┬──────────┬──────────┘  │   │
│  │         │          │          │          │              │   │
│  │  ┌──────▼──┐ ┌────▼─────┐ ┌──▼──────┐ ┌─▼──────────┐  │   │
│  │  │ WiFi    │ │ Sensor   │ │ Valve   │ │ Supabase   │  │   │
│  │  │ Manager │ │ Reader   │ │ Control │ │ Client     │  │   │
│  │  └─────────┘ └──────────┘ └─────────┘ └────────────┘  │   │
│  │  ┌────────────────────────────────────────────────────┐  │   │
│  │  │              Deep Sleep Manager                   │  │   │
│  │  └────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    HARDWARE INTERFACE                     │   │
│  │                                                          │   │
│  │  GPIO 34 ←─── Capacitive Soil Sensor v1.2 (Analog)      │   │
│  │  GPIO 26 ───→ Relay Module 1ch (5V) ───→ Solenoid 12V   │   │
│  │  GPIO 2  ───→ LED Indikator (Built-in)                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    COMMUNICATION                         │   │
│  │  WiFi ───→ Huawei B535-932 (4G LTE Router) ───→ Internet │   │
│  │               ↓ HTTP REST API                            │   │
│  │         Supabase (PostgreSQL + REST)                     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    POWER MANAGEMENT                      │   │
│  │  Aki 100Ah 12V ──→ Step-down 5V/2A ──→ ESP32            │   │
│  │                               └──→ Relay Module          │   │
│  │  ──→ 12V Langsung ──→ Solenoid Valve 12V NC             │   │
│  │  ──→ 12V Langsung ──→ Huawei B535 Router                │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

### Arsitektur Perangkat Keras (Wiring)

```
                  ┌──────────────────────────┐
                  │      ESP32 DevKit        │
                  │                          │
                  │  GPIO 2 ───→ LED (built-in)│
                  │  GPIO 26 ──→ Relay (IN)   │
                  │  GPIO 34 ←── Sensor (OUT) │
                  │  3.3V ────→ Sensor VCC    │
                  │  GND ─────→ Sensor GND    │
                  │          → Relay GND      │
                  │          → PSU GND        │
                  │  5V ─────→ Relay VCC      │
                  └──────────┬───────────────┘
                             │
                    ┌────────▼────────┐
                    │  Step-Down      │
                    │  12V → 5V/2A   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   Aki 100Ah     │
                    │   12V DC        │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼──────┐ ┌────▼────┐ ┌───────▼─────┐
     │  Solenoid     │ │ Huawei  │ │ Solar       │
     │  Valve 12V NC │ │ B535    │ │ Panel 300Wp │
     │  (Relay NO)   │ │ Router  │ │ + SCC 20A   │
     └───────────────┘ └─────────┘ └─────────────┘
```

---

## 🔄 State Machine Firmware

Setiap siklus ESP32 mengikuti state machine berikut:

```
    ┌──────────────────────────────────────────────────────┐
    │                    🟢 BOOT                            │
    │  ┌────────────────────────────────────┐              │
    │  │ - Serial init (115200)             │              │
    │  │ - Pin mode (LED, Relay)            │              │
    │  │ - Valve init (Relay LOW/CLOSED)    │              │
    │  └─────────────────┬──────────────────┘              │
    └────────────────────┼─────────────────────────────────┘
                         │
                         ▼
    ┌──────────────────────────────────────────────────────┐
    │                📶 KONEKSI WiFi                        │
    │  ┌────────────────────────────────────┐              │
    │  │ WiFi.begin(SSID, PASS)             │              │
    │  │ Timeout: 10 detik                  │              │
    │  │ ┌── Success ──→ Lanjut             │              │
    │  │ └── Failed ───→ Deep Sleep ⏰      │              │
    │  └─────────────────┬──────────────────┘              │
    └────────────────────┼─────────────────────────────────┘
                         │
                         ▼
    ┌──────────────────────────────────────────────────────┐
    │              🌱 BACA SENSOR                           │
    │  ┌────────────────────────────────────┐              │
    │  │ analogRead(GPIO 34)                │              │
    │  │ raw: 1500 (basah) → 2700 (kering)  │              │
    │  │ Konversi → moisture_percent (0-100)│              │
    │  └─────────────────┬──────────────────┘              │
    └────────────────────┼─────────────────────────────────┘
                         │
                         ▼
    ┌──────────────────────────────────────────────────────┐
    │            ⚙️ AMBIL KONFIGURASI                       │
    │  ┌────────────────────────────────────┐              │
    │  │ GET /system_config?device_id=eq.X │              │
    │  │ → mode (auto/manual)              │              │
    │  │ → threshold_dry (default: 30%)    │              │
    │  │ → threshold_wet (default: 70%)    │              │
    │  │ → valve_duration (default: 30s)   │              │
    │  │ → read_interval (default: 1800s)  │              │
    │  │ ┌── Success ──→ Pakai dari cloud  │              │
    │  │ └── Failed ───→ Pakai default     │              │
    │  └─────────────────┬──────────────────┘              │
    └────────────────────┼─────────────────────────────────┘
                         │
                         ▼
    ┌──────────────────────────────────────────────────────┐
    │              📋 CEK PERINTAH                          │
    │  ┌────────────────────────────────────┐              │
    │  │ GET /pending_commands?             │              │
    │  │   device_id=eq.X&status=eq.pending │              │
    │  │                                    │              │
    │  │ ┌── Ada perintah ──→ Eksekusi ──┐ │              │
    │  │ │  VALVE_ON:duration → Buka valve│ │              │
    │  │ │  VALVE_OFF        → Tutup valve│ │              │
    │  │ │  → PATCH status=executed      │ │              │
    │  │ └── Tidak ada ───→ Cek mode auto │ │              │
    │  │ ┌── Mode auto ─────────────────┐ │ │              │
    │  │ │  threshold < kering (30%)    │ │ │              │
    │  │ │  → Buka valve (duration)     │ │ │              │
    │  │ │  threshold > basah (70%)     │ │ │              │
    │  │ │  → Valve tetap CLOSED        │ │ │              │
    │  │ └──────────────────────────────┘ │ │              │
    │  └─────────────────┬──────────────────┘              │
    └────────────────────┼─────────────────────────────────┘
                         │
                         ▼
    ┌──────────────────────────────────────────────────────┐
    │           ✅ PASTIKAN VALVE TERTUTUP                  │
    │  ┌────────────────────────────────────┐              │
    │  │ digitalWrite(RELAY_PIN, LOW)       │              │
    │  │ → Safety: valve selalu CLOSED      │              │
    │  │    sebelum tidur                   │              │
    │  └─────────────────┬──────────────────┘              │
    └────────────────────┼─────────────────────────────────┘
                         │
                         ▼
    ┌──────────────────────────────────────────────────────┐
    │            📤 KIRIM DATA SENSOR                       │
    │  ┌────────────────────────────────────┐              │
    │  │ Baca sensor sekali lagi (post-valve)│              │
    │  │ POST /sensor_readings              │              │
    │  │ {                                  │              │
    │  │   device_id, moisture,             │              │
    │  │   moisture_percent, valve_status   │              │
    │  │ }                                  │              │
    │  └─────────────────┬──────────────────┘              │
    └────────────────────┼─────────────────────────────────┘
                         │
                         ▼
    ┌──────────────────────────────────────────────────────┐
    │            📴 MATIKAN WiFi & TIDUR                    │
    │  ┌────────────────────────────────────┐              │
    │  │ WiFi.disconnect(true)              │              │
    │  │ WiFi.mode(WIFI_OFF)                │              │
    │  │ esp_deep_sleep_start()             │              │
    │  │ → Konsumsi ~5 µA                   │              │
    │  │ → Bangun setelah read_interval     │              │
    │  └────────────────────────────────────┘              │
    └──────────────────────────────────────────────────────┘
```

### Timeline Satu Siklus (30 Menit)

```
         Bangun                    Tidur lagi zzz...
           │                             │
           ▼                             ▼
    ┌──────────────┬──────┬──────┬──────┬──────────────┐
    │  Deep Sleep  │ WiFi │Sensr │Cloud │  Deep Sleep  │
    │  29:57       │:01   │:001  │:009  │  29:57       │
    │  ~5 µA       │~80mA │~12mA │~80mA │  ~5 µA       │
    └──────────────┴──────┴──────┴──────┴──────────────┘
    ├── 29 menit 57 dtk ──┤├── 3 detik aktif ─┤├── 29:57 ─┤
```

> **Total waktu aktif:** ~3 detik per siklus (0,017% dari total waktu)

---

## 📁 Struktur Kode

```
hardware/firmware/
├── platformio.ini              ← Build config (board, libs, flags)
├── include/
│   ├── config.h                ← Konfigurasi utama (WiFi, Supabase, PIN)
│   ├── wifi_manager.h          ← Header koneksi WiFi
│   ├── sensor.h                ← Header pembacaan sensor
│   ├── valve.h                 ← Header kontrol solenoid valve
│   ├── supabase_client.h       ← Header HTTP Supabase API
│   ├── deep_sleep.h            ← Header manajemen deep sleep
│   └── devices/
│       ├── petak_01.h          ← Device ID: "petak-01"
│       ├── petak_02.h          ← Device ID: "petak-02"
│       ├── petak_03.h          ← Device ID: "petak-03"
│       ├── petak_04.h          ← Device ID: "petak-04"
│       ├── petak_05.h          ← Device ID: "petak-05"
│       └── petak_06.h          ← Device ID: "petak-06"
└── src/
    ├── main.cpp                ← Siklus utama (setup → loop → deep sleep)
    ├── wifi_manager.cpp        ← WiFi connect/disconnect
    ├── sensor.cpp              ← Baca ADC → moisture percent
    ├── valve.cpp               ← Buka/tutup valve via relay
    ├── supabase_client.cpp     ← HTTP client untuk semua endpoint Supabase
    └── deep_sleep.cpp          ← Timer wakeup + deep sleep
```

### Data Structures

```cpp
// sensor.h
struct SensorReading {
  int raw;              // ADC 12-bit: 0-4095
  float percent;        // 0.0 (kering) - 100.0 (basah)
};

// valve.h
// State: static bool valveOpen (internal)
// Safety: VALVE_MAX_DURATION_MS = 120000 (2 menit maks)

// supabase_client.h
struct SystemConfig {
  String mode;          // "auto" | "manual"
  int thresholdDry;     // Default: 30%
  int thresholdWet;     // Default: 70%
  int valveDurationMs;  // Default: 30000 (30 detik)
  int readIntervalSec;  // Default: 1800 (30 menit)
  bool valid;           // Apakah berhasil dari cloud?
};

struct PendingCommand {
  long id;              // ID row di Supabase
  String command;       // "VALVE_ON" | "VALVE_OFF"
  int duration;         // Durasi dalam detik
  bool valid;           // Apakah ada command?
};
```

### Dependency Graph

```
main.cpp
  ├── config.h               (WiFi SSID, pin, default, Supabase URL/key)
  ├── wifi_manager.h/.cpp    (connect/disconnect)
  ├── sensor.h/.cpp          (readSensor → analogRead)
  ├── valve.h/.cpp           (init, open, close, isOpen)
  ├── supabase_client.h/.cpp (HTTP POST/GET/PATCH via ArduinoJson)
  └── deep_sleep.h/.cpp      (esp_sleep_enable_timer_wakeup)

supabase_client.cpp
  └── config.h               (URL, key, defaults)
  └── HTTPClient.h           (ESP32 WiFiClient)
  └── ArduinoJson.h          (StaticJsonDocument)
```

---

## 🔧 Konfigurasi Multi-Petak

### Device IDs

| Petak | File Header | Device ID | Lahan |
|-------|-------------|-----------|-------|
| Petak 1 | `devices/petak_01.h` | `petak-01` | Lahan A |
| Petak 2 | `devices/petak_02.h` | `petak-02` | Lahan A |
| Petak 3 | `devices/petak_03.h` | `petak-03` | Lahan A |
| Petak 4 | `devices/petak_04.h` | `petak-04` | Lahan B |
| Petak 5 | `devices/petak_05.h` | `petak-05` | Lahan B |
| Petak 6 | `devices/petak_06.h` | `petak-06` | Lahan B |

### Cara Flash untuk Petak Berbeda

1. Buka `hardware/firmware/include/config.h`
2. Ubah baris `#include "devices/petak_XX.h"` sesuai petak tujuan
3. Build & flash:

```bash
cd hardware/firmware
pio run --target upload
```

> Setiap ESP32 hanya menjalankan SATU petak. Butuh 6 unit ESP32 untuk 6 petak.

---

## 📌 Pin Mapping & Wiring

### Pin ESP32

| GPIO | Fungsi | Koneksi | Keterangan |
|:----:|--------|---------|------------|
| GPIO 2 | LED Indikator | LED Built-in ESP32 | Menyala saat aktif |
| GPIO 26 | Relay Control | Relay Module (IN) | HIGH = valve ON, LOW = OFF |
| GPIO 34 | Sensor ADC | Capacitive Soil Sensor (OUT) | ADC 12-bit, input-only |
| 3.3V | Sensor VCC | Sensor VCC | Max 50mA dari pin 3.3V |
| 5V | Relay VCC | Relay Module VCC | Dari step-down 12V→5V |
| GND | Ground | Sensor, Relay, PSU | Common ground |

> **⚠️ Catatan:** GPIO 34 adalah input-only (tidak punya internal pull-up). Tidak masalah untuk ADC.

### Wiring Diagram Detail

```
ESP32 DevKit                  Capacitive Soil Sensor v1.2
┌──────────┐                  ┌────────────────────┐
│ GPIO 34  │◄────────────────┤ OUT (Kuning)       │
│ 3.3V     │─────────────────┤ VCC (Merah)        │
│ GND      │◄────────────────┤ GND (Hitam)        │
└──────────┘                  └────────────────────┘

ESP32 DevKit                  Relay Module 1ch 5V
┌──────────┐                  ┌────────────────────┐
│ GPIO 26  │─────────────────┤ IN (Sinyal)        │
│ 5V       │─────────────────┤ VCC                │
│ GND      │◄────────────────┤ GND                │
└──────────┘                  └────────┬───────────┘
                                       │
                              ┌────────▼───────────┐
                              │ Solenoid Valve 12V  │
                              │ NC (Normally Closed)│
                              │                     │
                              │ COM ─── PSU 12V (+) │
                              │ NO  ─── Valve (+)   │
                              │ Valve (-) ── GND    │
                              └─────────────────────┘
```

---

## 📡 Protokol Komunikasi Supabase

### Endpoint REST API

| Method | Endpoint | Arah | Frekuensi | Payload |
|--------|----------|------|-----------|---------|
| **POST** | `/rest/v1/sensor_readings` | ESP32 → Cloud | Tiap siklus | `{device_id, moisture, moisture_percent, valve_status}` |
| **GET** | `/rest/v1/system_config?device_id=eq.X` | Cloud → ESP32 | Tiap siklus | Array `[SystemConfig]` |
| **GET** | `/rest/v1/pending_commands?device_id=eq.X&status=eq.pending` | Cloud → ESP32 | Tiap siklus | Array `[PendingCommand]` |
| **PATCH** | `/rest/v1/pending_commands?id=eq.X` | ESP32 → Cloud | Setelah eksekusi | `{status: "executed"}` |

### Header HTTP (Semua Request)

```http
apikey: <SUPABASE_ANON_KEY>
Authorization: Bearer <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=minimal
```

### Flow Data Lengkap

```
                        SUPABASE (PostgreSQL)
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  ┌────────────────┐  ┌──────────────────┐  ┌────────────────┐   │
│  │ sensor_readings│  │ pending_commands │  │ system_config  │   │
│  │                │  │                  │  │                │   │
│  │ ↑ WRITE (ESP) │  │ ↑ WRITE (Flutter)│  │ ↑ WRITE (Flutr)│   │
│  │ ↓ READ (Flutr)│  │ ↓ READ (ESP)     │  │ ↓ READ (ESP)   │   │
│  └────────────────┘  └──────────────────┘  └────────────────┘   │
│         ▲                    │                      ▲            │
│         │                    │ PATCH status         │            │
│         │                    ▼  = executed          │            │
│         │              ┌──────────────┐            │             │
│         │              │ ESP32 proses │            │             │
│         │              │ perintah     │            │             │
│         │              └──────────────┘            │             │
│         └──────────────────────────────────────────┘             │
│                                                                  │
│  Realtime Publication ──→ Flutter App (auto sync)                │
└──────────────────────────────────────────────────────────────────┘
```

### ArduinoJson — Alokasi Memori

```cpp
// Dokumen JSON statis (stack, bukan heap)
StaticJsonDocument<256> sensorPayload;   // POST sensor_readings
StaticJsonDocument<512> configResponse;  // GET system_config (parse)
StaticJsonDocument<512> cmdResponse;     // GET pending_commands (parse)
StaticJsonDocument<128> cmdUpdate;       // PATCH command status
```

> Total: ~1.4KB stack — aman untuk ESP32 (320KB SRAM).

---

## ⚡ Manajemen Daya & Deep Sleep

### Konsumsi Daya per Mode

| Mode | Arus | Daya (12V) | Durasi per Siklus | % Waktu |
|------|:----:|:----------:|:------------------:|:-------:|
| **Deep Sleep** | ~5 µA | 0,06 mW | 29 menit 57 detik | 99,83% |
| **WiFi Connect** | ~80 mA | 960 mW | ~1 detik | 0,06% |
| **Sensor Baca** | ~12 mA | 144 mW | ~0,1 detik | 0,006% |
| **HTTP (TX/RX)** | ~80 mA | 960 mW | ~1,9 detik | 0,11% |
| **Valve ON** | ~500 mA | 6 W | 30 detik (sesuai config) | ~0,07%* |

\*Valve ON tidak terjadi tiap siklus — hanya saat tanah kering atau ada perintah manual.

### Rata-rata Konsumsi

```
Rata-rata per siklus (30 menit, tanpa valve):
≈ 0,3 mA  →  1,5 mW  →  36 mWh per siklus

Dengan aki 100Ah (1200Wh):
~138 hari tanpa solar panel
~∞ dengan panel 300Wp (isi ulang 3-4 jam)
```

### Implementasi Deep Sleep

```cpp
// deep_sleep.cpp
void goToSleep(uint64_t sleepSeconds) {
  Serial.flush();                                                  // Flush serial sebelum mati
  uint64_t sleepUs = sleepSeconds * 1000000ULL;                    // Konversi detik → mikrodetik
  esp_sleep_enable_timer_wakeup(sleepUs);                          // Timer wakeup
  esp_deep_sleep_start();                                          // Tidur — kode setelah ini tidak jalan
}
```

### Wake-up Sources

| Source | Digunakan? | Keterangan |
|--------|:---------:|------------|
| Timer | ✅ **(Ya)** | esp_sleep_enable_timer_wakeup — interval dari `read_interval` |
| Touch | ❌ | Tidak dipakai (boros daya) |
| GPIO | ❌ | Tidak dipakai |
| ULP | ❌ | Tidak dipakai |

> **Catatan:** Karena ESP32 dalam deep sleep, **tidak ada perintah realtime**. Perintah dari aplikasi baru dieksekusi pada siklus berikutnya saat ESP32 bangun. Ini adalah trade-off untuk efisiensi daya.

---

## 📐 Kalibrasi Sensor Kelembaban

### Formula Konversi

```cpp
// sensor.cpp
int raw = analogRead(SENSOR_PIN);         // ADC 12-bit: 0-4095

// Kapasitif: kering ≈ 2700, basah ≈ 1500
float percent = 100.0f - ((raw - 1500.0f) / (2700.0f - 1500.0f)) * 100.0f;

// Clamp
if (percent < 0.0f) percent = 0.0f;
if (percent > 100.0f) percent = 100.0f;
```

### Threshold Default

| Parameter | Default | Via Aplikasi? |
|-----------|:-------:|:-------------:|
| Kering (threshold_dry) | 30% | ✅ Bisa diubah |
| Basah (threshold_wet) | 70% | ✅ Bisa diubah |

### Logika Kontrol

```
moisture_percent < threshold_dry (30%)
  → Tanah KERING → Buka valve (valve_duration)
  
threshold_dry ≤ moisture_percent ≤ threshold_wet  
  → Lembab → Valve tetap CLOSED
  
moisture_percent > threshold_wet (70%)
  → Tanah BASAH → Valve tetap CLOSED
```

### Prosedur Kalibrasi Lapangan

1. Tanam sensor di tanah yang **benar-benar basah** (setelah hujan/siram)
2. Catat nilai ADC — ini jadi `WET_REFERENCE`
3. Biarkan tanah mengering 2-3 hari
4. Catat nilai ADC saat tanah **sangat kering** — ini jadi `DRY_REFERENCE`
5. Update di `sensor.cpp`:

```cpp
float percent = 100.0f - ((raw - WET_REFERENCE) / (DRY_REFERENCE - WET_REFERENCE)) * 100.0f;
```

> Untuk padi: threshold basah lebih tinggi (80%), threshold kering lebih rendah (20%)
> Untuk cabai: threshold basah 60%, kering 30%

---

## 🛡️ Safety & Fail-Safe

### 1. Solenoid Valve Normally Closed (NC)

Valve dalam kondisi **NC (Normally Closed)** — saat:
- ESP32 mati / reset
- Relay mati / rusak
- WiFi putus
- Aki habis

→ Valve **OTOMATIS TERTUTUP** (tidak mengalirkan air).

### 2. Valve Max Duration (2 Menit)

```cpp
#define VALVE_MAX_DURATION_MS 120000   // 2 menit maksimal

void openValve(int durationMs) {
  if (durationMs > VALVE_MAX_DURATION_MS) {
    durationMs = VALVE_MAX_DURATION_MS;   // Paksa ke maks
  }
  if (durationMs < 1000) {
    durationMs = 1000;                    // Minimal 1 detik
  }
  // ...
}
```

### 3. Valve Pasti Tutup Sebelum Tidur

```cpp
// main.cpp — sebelum deep sleep
closeValve();  // Relay LOW → Valve NC → TERTUTUP
```

### 4. WiFi Timeout

```cpp
#define WIFI_TIMEOUT_MS 10000   // 10 detik timeout

// Kalau gagal WiFi → langsung deep sleep, coba lagi nanti
if (!connectWiFi()) {
  goToSleep(DEFAULT_READ_INTERVAL_SEC);
}
```

### 5. Fallback Konfigurasi

```cpp
// Kalau GET system_config gagal → pakai nilai default
SystemConfig config = getSystemConfig(DEVICE_ID);
if (!config.valid) {
  // Pakai DEFAULT_THRESHOLD_DRY, DEFAULT_THRESHOLD_WET, dll.
}
```

### 6. Kapasitor Filter ADC

```cpp
// Kapasitor 100nF antara GPIO 34 dan GND
// → Menstabilkan pembacaan ADC, mengurangi noise
```

### 7. Anti Water Hammer

Solenoid valve membuka/menutup secara perlahan (built-in pada valve 12V NC). Tidak perlu software tambahan.

---

## 🛠️ PlatformIO Build System

### `platformio.ini`

```ini
[platformio]
src_dir = src
include_dir = include

[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
lib_deps =
    bblanchon/ArduinoJson @ ^6.21.3
build_flags =
    -DCORE_DEBUG_LEVEL=3
    -Wno-unused-variable
    -Wno-unused-but-set-variable
```

### Library Dependencies

| Library | Versi | Fungsi |
|---------|-------|--------|
| **ArduinoJson** | ^6.21.3 | JSON serialization/deserialization untuk HTTP payload |
| **WiFi** | Built-in | ESP32 WiFi station mode |
| **HTTPClient** | Built-in | HTTP REST client |
| **esp_sleep** | Built-in | Deep sleep + timer wakeup |

### Command Build & Flash

```bash
# Build (compile saja)
pio run

# Build + flash ke ESP32 via USB
pio run --target upload

# Monitor serial
pio device monitor

# Clean build cache
pio run --target clean

# Build + flash untuk petak tertentu
# (Edit config.h dulu: ganti include devices/petak_XX.h)
pio run --target upload
```

### Folder `.pio/` (Build Output)

```
.pio/
├── build/
│   └── esp32dev/
│       ├── firmware.bin          ← Binary untuk di-flash
│       ├── partitions.bin        ← Partisi
│       ├── bootloader.bin        ← Bootloader
│       └── ...
└── libdeps/
    └── esp32dev/
        └── ArduinoJson/         ← Library yang di-download
```

---

## 🐛 Troubleshooting

### Masalah WiFi

| Gejala | Penyebab | Solusi |
|--------|----------|--------|
| WiFi timeout terus | Router mati/jauh | Cek jarak ESP32 ke router, tambah antena |
| Koneksi lambat | Sinyal 4G lemah | Cek posisi antena outdoor Huawei B535 |
| Connect tapi HTTP gagal | Supabase offline | Cek status Supabase |

### Masalah Sensor

| Gejala | Penyebab | Solusi |
|--------|----------|--------|
| ADC selalu 4095 | Sensor tidak terhubung | Cek kabel GPIO 34 |
| ADC selalu 0 | Sensor short ke GND | Cek kabel VCC/GND |
| Nilai tidak stabil | Noise ADC | Tambah kapasitor 100nF, atau averaging |
| Persentase aneh | Kalibrasi rusak | Update DRY_REFERENCE dan WET_REFERENCE |

### Masalah Valve

| Gejala | Penyebab | Solusi |
|--------|----------|--------|
| Valve tidak ON | Relay rusak | Cek relay module dgn LED tester |
| Valve tidak OFF (macet) | Kotor/mekanik | Bongkar, bersihkan solenoid valve |
| Valve ON terus | Relay short | Ganti relay module |
| Air tidak mengalir | Selang tersumbat | Cek saluran drip irrigation |

### Masalah Daya

| Gejala | Penyebab | Solusi |
|--------|----------|--------|
| ESP32 restart terus | Tegangan drop saat valve ON | Cek step-down, pastikan 2A cukup |
| Aki cepat habis | Solar panel tidak cukup | Cek SCC, panel, atau cuaca |
| ESP32 mati total | Aki kosong | Cek tegangan aki (min 11.5V) |

### Debug via Serial

```bash
pio device monitor
# Output:
# ANDROMEDA firmware starting
# Device ID: petak-01
# Connecting to WiFi....
# Connected IP: 192.168.8.100
# Sensor raw: 2200 -> percent: 42.5
# GET system_config: [{"mode":"auto",...}]
# GET pending_commands: [...]
# Soil dry, opening valve
# Opening valve for 30000 ms
# Valve closed
# POST sensor_readings: {"device_id":"petak-01","moisture":2200,...}
# Response code: 201
# Going to sleep for 1800 seconds
```

---

## 📊 Ringkasan Spesifikasi ESP32

| Parameter | Spesifikasi |
|-----------|-------------|
| **Mikrokontroler** | ESP32 DevKit (30 pin) — Xtensa LX6 dual-core 240MHz |
| **Framework** | Arduino (C++11) via PlatformIO |
| **ADC** | 12-bit (0-4095), GPIO 34 |
| **WiFi** | 802.11 b/g/n (station mode) |
| **Rata-rata Konsumsi** | ~0,3 mA / ~1,5 mW |
| **Deep Sleep** | ~5 µA |
| **Interval Siklus** | 30 menit (dapat diatur via Supabase) |
| **Durasi Aktif per Siklus** | ~3 detik |
| **Komunikasi Cloud** | HTTP REST + JSON |
| **Backend** | Supabase (PostgreSQL) |
| **Valve Safety** | Normally Closed (fail-safe) |
| **Max Valve ON** | 120 detik (software limit) |
| **Multi-petak** | 6 device ID, 1 ESP32 per petak |
| **Total Unit** | 6 × ESP32 (1 per petak) |

---

> 🌾 *ANDROMEDA — Dari petani, oleh petani, untuk petani.*  
> *Dokumen arsitektur ini mencakup seluruh detail ESP32 sebagai otak sistem irigasi tetes otomatis.*
