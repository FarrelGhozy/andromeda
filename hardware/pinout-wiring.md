# Pinout & Wiring ANDROMEDA — ESP32-01 & ESP32-02

## Gambaran Sistem

Setiap **ESP32 DevKit 30-pin** menangani **6 petak** (bedengan) sekaligus.
Total ada **2 unit ESP32** untuk 12 petak:

| ESP32 | Petak | Lahan | Lokasi |
|-------|-------|-------|--------|
| **esp32-01** | petak-01 s.d. petak-06 | Lahan A | |
| **esp32-02** | petak-07 s.d. petak-12 | Lahan B | |

---

## Layout Fisik ESP32 DevKit 30-Pin

```
                    ┌─────────────────────────────┐
                    │                             │
        ┌─── USB ───┤                             ├─── EN ───┐
        │           │                             │          │
    (TX) GPIO 1 ◄──┤                             ├──► GPIO 3 (RX)
         (RX) GPIO 3 ◄──┤                             ├──► GPIO 1 (TX)
                    │                             │
         GPIO 21 ◄──┤                             ├──► GPIO 22
         GPIO 19 ◄──┤                             ├──► GPIO 23
         GPIO 18 ◄──┤                             ├──► GPIO 17
          GPIO 5 ◄──┤                             ├──► GPIO 16
         GPIO 25 ◄──┤                             ├──► GPIO 4
         GPIO 26 ◄──┤  ⚡ RELAY 1 (petak-01/07)  ├──► GPIO 0  (BOOT — jangan dipakai)
         GPIO 27 ◄──┤  ⚡ RELAY 2 (petak-02/08)  ├──► GPIO 2  (💡 LED built-in)
         GPIO 14 ◄──┤  ⚡ RELAY 3 (petak-03/09)  ├──► GPIO 15 ⚡ RELAY 6 (petak-06/12)
         GPIO 12 ◄──┤  ⚡ RELAY 4 (petak-04/10)  ├──► GPIO 13 ⚡ RELAY 5 (petak-05/11)
          GND  ◄──┤                             ├──► GND
         VP / 36 ◄──┤  🌱 SENSOR 5 (petak-05/11) ├──► VIN (5V input)
         VN / 39 ◄──┤  🌱 SENSOR 6 (petak-06/12) ├──► 3.3V (output)
    D34 / GPIO 34 ◄──┤  🌱 SENSOR 3 (petak-03/09) ├──► 5V  (output dari USB/VIN)
    D35 / GPIO 35 ◄──┤  🌱 SENSOR 4 (petak-04/10) ├──► GND
    GPIO 32 ◄──┤  🌱 SENSOR 1 (petak-01/07) ├──► GPIO 33 🌱 SENSOR 2 (petak-02/08)
          GND  ◄──┤                             ├──► GND
         GPIO 4 ◄──┤                             ├──► GPIO 5
                    └─────────────────────────────┘
```

---

## Tabel Pin Lengkap

### 🌱 Sensor Kelembaban Tanah (Capacitive Soil Sensor v1.2)

| Petak (esp32-01) | Petak (esp32-02) | GPIO ESP32 | Pin Fisik | Fungsi |
|:----------------:|:----------------:|:----------:|:---------:|--------|
| petak-01 | petak-07 | **GPIO 32** | ADC1_CH4 | Sensor 1 — ADC 12-bit |
| petak-02 | petak-08 | **GPIO 33** | ADC1_CH5 | Sensor 2 — ADC 12-bit |
| petak-03 | petak-09 | **GPIO 34** | ADC1_CH6 | Sensor 3 — ADC 12-bit (input-only) |
| petak-04 | petak-10 | **GPIO 35** | ADC1_CH7 | Sensor 4 — ADC 12-bit (input-only) |
| petak-05 | petak-11 | **GPIO 36** | ADC1_CH0 | Sensor 5 — ADC 12-bit (input-only) |
| petak-06 | petak-12 | **GPIO 39** | ADC1_CH3 | Sensor 6 — ADC 12-bit (input-only) |

**Kabel Sensor (Capacitive Soil v1.2):**
| Kabel Sensor | Hubungkan ke | Catatan |
|--------------|-------------|---------|
| **OUT** (kuning) | GPIO sensor sesuai tabel di atas | Output analog 0-3.3V |
| **VCC** (merah) | **3.3V** ESP32 | Max 50mA dari pin 3.3V |
| **GND** (hitam) | **GND** ESP32 | Common ground |

### ⚡ Relay — Solenoid Valve (1-Channel 5V Optocoupler)

| Petak (esp32-01) | Petak (esp32-02) | GPIO ESP32 | Pin Fisik | Fungsi |
|:----------------:|:----------------:|:----------:|:---------:|--------|
| petak-01 | petak-07 | **GPIO 26** | Digital | Relay 1 — Valve 1 |
| petak-02 | petak-08 | **GPIO 27** | Digital | Relay 2 — Valve 2 |
| petak-03 | petak-09 | **GPIO 14** | Digital | Relay 3 — Valve 3 |
| petak-04 | petak-10 | **GPIO 12** | Digital | Relay 4 — Valve 4 |
| petak-05 | petak-11 | **GPIO 13** | Digital | Relay 5 — Valve 5 |
| petak-06 | petak-12 | **GPIO 15** | Digital | Relay 6 — Valve 6 |

**Kabel Relay Module:**
| Terminal Relay | Hubungkan ke | Catatan |
|----------------|-------------|---------|
| **IN** (Sinyal) | GPIO relay sesuai tabel di atas | **HIGH** (3.3V) = relay ON, **LOW** (0V) = relay OFF |
| **VCC** | **5V** (dari step-down 12V→5V) | Relay 5V membutuhkan 5V, bukan 3.3V |
| **GND** | **GND** ESP32 & PSU | Common ground |

**Kontak Relay ke Solenoid Valve (12V NC):**
| Terminal Relay | Hubungkan ke | Catatan |
|----------------|-------------|---------|
| **COM** | **PSU 12V (+)** | Sumber listrik 12V untuk valve |
| **NO** (Normally Open) | **Valve (+)** | Valve ON saat relay aktif |
| NC (tidak dipakai) | - | Normally Closed — tidak digunakan |
| **Valve (−)** | **GND PSU 12V** | |

### 💡 LED Indikator

| GPIO | Pin Fisik | Fungsi | Warna | Resistor |
|:----:|:---------:|--------|:-----:|:--------:|
| **GPIO 2** | Digital | LED built-in (kebanyakan ESP32 Dev) | Biru | Built-in |
| GPIO 2 | Digital | LED eksternal (jika built-in tidak ada) | Biru/Merah | 220Ω |

### ⚡ Power

| Jalur | Tegangan | Sumber | Tujuan | Catatan |
|-------|:--------:|--------|--------|---------|
| **ESP32 VIN** | 5V | Step-down 12V→5V | ESP32 input power | Max 2A |
| **ESP32 3.3V** | 3.3V | Regulator ESP32 | Sensor VCC | Max 50mA |
| **Relay VCC** | 5V | Step-down 12V→5V | Relay module | 1 relay ~70mA |
| **Valve (+)** | 12V | Aki 12V langsung | Solenoid valve NC | ~300-500mA saat ON |
| **Router** | 12V | Aki 12V langsung | Huawei B535 | ~1-2A |

---

## Wiring Diagram Detail

### 1 Sensor — 1 Relay — 1 Valve (contoh petak-01 / petak-07)

```
  ESP32 DevKit              Capacitive Soil Sensor v1.2
  ┌──────────────┐          ┌────────────────────┐
  │ GPIO 32 ◄────┼──────────┤ OUT (kuning)       │
  │ 3.3V ────────┼──────────┤ VCC (merah)        │
  │ GND ◄────────┼──────────┤ GND (hitam)        │
  └──────────────┘          └────────────────────┘

  ESP32 DevKit              Relay 1ch 5V Optocoupler
  ┌──────────────┐          ┌────────────────────┐
  │ GPIO 26 ─────┼──────────┤ IN                 │
  │ 5V ──────────┼──────────┤ VCC                │
  │ GND ◄────────┼──────────┤ GND                │
  └──────────────┘          └────────┬───────────┘
                                     │
                            ┌────────▼───────────┐
                            │  Solenoid Valve     │
                            │  12V NC 1/2"        │
                            │                     │
                            │ COM ─── PSU 12V (+) │
                            │ NO  ─── Valve (+)   │
                            │ Valve (−) ── GND    │
                            └─────────────────────┘
```

### Diagram Power Keseluruhan

```
                    ┌─────────────────┐
                    │   Aki 12V 100Ah │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────────┐
              │              │                   │
     ┌────────▼──────┐  ┌───▼────┐       ┌──────▼──────┐
     │ Step-Down     │  │ MCB    │       │ Solar Panel │
     │ 12V → 5V/2A   │  │ 6A     │       │ 300Wp + SCC │
     └───────┬───────┘  └───┬────┘       └─────────────┘
             │              │
     ┌───────┼───────┐      └───── 12V Langsung ────┐
     │       │       │                               │
     ▼       ▼       ▼                               ▼
  ┌─────┐ ┌─────┐ ┌─────┐                    ┌──────────┐
  │ESP32│ │Relay│ │Relay│ ... x6              │Huawei    │
  │VIN  │ │VCC  │ │VCC  │                     │B535      │
  └─────┘ └─────┘ └─────┘                    │Router 4G │
                                              └──────────┘

  12V Langsung ────────────────────────────────────────┐
                                                       ▼
                                              ┌──────────────┐
                                              │ Solenoid Valve│
                                              │ 12V (COIL +) │
                                              └──────────────┘
```

---

## Pertimbangan Penting

### ⚠️ GPIO 12 (MTDI)
- GPIO 12 adalah pin **MTDI** yang menentukan tegangan flash internal (3.3V/1.8V).
- Ada **pull-up 10kΩ** internal yang bisa mengubah mode boot.
- **Jangan** menarik GPIO 12 ke LOW saat boot/startup.
- Relay module harus dalam kondisi **OFF (LOW)** saat ESP32 boot.

### ⚠️ GPIO 34, 35, 36, 39 (Input-Only)
- GPIO ini **tidak bisa output** — tidak punya internal pull-up/pull-down.
- Cocok untuk ADC karena tidak ada noise dari switching digital.
- Sensor harus **selalu terhubung** (jika tidak, ADC membaca nilai acak/floating).

### ⚠️ GPIO 0 (Boot Mode)
- GPIO 0 menentukan mode **flash/download** jika LOW saat boot.
- **Jangan** gunakan GPIO 0 untuk relay/sensor.
- Ini aman (tidak dipakai), tapi perlu diingat saat testing/troubleshooting.

### ⚠️ GPIO 2 (LED)
- GPIO 2 harus **HIGH** atau **floating** saat boot.
- LED built-in biasanya aktif LOW (menyala saat GPIO 2 = LOW).
- LED eksternal: anoda → 220Ω → GPIO 2, katoda → GND.

### ⚠️ Relay — Trigger Level
- Relay module 5V dengan optocoupler bisa trigger di **3.3V** (cukup untuk ESP32).
- Pastikan relay membeli yang **HIGH trigger** (bukan LOW trigger).
- Relay **LOW trigger** butuh logic inverter.

### ⚠️ Kapasitor Filter ADC
- Pasang **kapasitor 100nF** antara setiap GPIO sensor dan GND.
- Fungsi: menstabilkan ADC, mengurangi noise dari kabel panjang (10-20m).

### ⚠️ Kabel Sensor Panjang (10-20m)
- Gunakan **kabel shielded** (Belden 3107A atau UTP Cat5e) untuk sensor.
- Shield kabel dihubungkan ke **GND** di sisi ESP32 saja (satu sisi).
- Panjang maksimal: ~20m (dengan kapasitor 100nF di kedua sisi).

### ⚠️ Ground Bersama (Common Ground)
- Semua ground harus terhubung: ESP32, sensor, relay, PSU 5V, PSU 12V, valve.
- Jika tidak, sinyal ADC akan floating dan relay tidak bisa trigger.

### ⚠️ Valve — Normally Closed (NC)
- Pastikan valve adalah tipe **NC (Normally Closed)**.
- Saat ESP32 mati, deep sleep, reset, atau aki habis:
  - Relay OFF → NO terbuka → Valve tertutup → Aman.
- Valve **NO (Normally Open)** akan membuka saat listrik mati — bahaya banjir!

### ⚠️ Max Arus per Pin
| Pin | Max Arus | Pemakaian | Aman? |
|-----|:--------:|:---------:|:-----:|
| GPIO output | 40mA | Relay IN (~1-5mA) | ✅ Aman |
| 3.3V output | 50mA | 6 sensor × ~5mA = 30mA | ✅ Aman |
| 5V (VIN) | 2A | ESP32 ~80mA + 6 relay × 70mA = 500mA | ✅ Aman |
| Total via USB | 500mA | - | ⚠️ Jangan pakai USB untuk valve |

---

## Perbandingan esp32-01 vs esp32-02

| Aspek | esp32-01 | esp32-02 |
|-------|:--------:|:--------:|
| ESP32 ID | `esp32-01` | `esp32-02` |
| Petak | 01 — 06 | 07 — 12 |
| Lahan | A | B |
| Sensor GPIO | 32, 33, 34, 35, 36, 39 | 32, 33, 34, 35, 36, 39 |
| Relay GPIO | 26, 27, 14, 12, 13, 15 | 26, 27, 14, 12, 13, 15 |
| LED GPIO | 2 | 2 |
| **Wiring** | **IDENTIK** | **IDENTIK** |

> Kedua ESP32 memiliki **pinout yang persis sama**. Yang membedakan hanyalah device ID dan petak ID di software.

---

## Ceklist Pemasangan

- [ ] Kapasitor 100nF terpasang di setiap GPIO sensor → GND
- [ ] Sensor VCC ke 3.3V (bukan 5V!)
- [ ] Relay VCC ke 5V step-down
- [ ] Relay GND ke GND ESP32 + PSU
- [ ] COM relay ke PSU 12V (+)
- [ ] NO relay ke Valve (+)
- [ ] Valve (−) ke GND PSU 12V
- [ ] Valve tipe **NC (Normally Closed)**
- [ ] Step-down 12V→5V terkalibrasi (ukur output 5V ±0.25V)
- [ ] Kabel sensor menggunakan shielded twisted pair
- [ ] Shield hanya di-ground di sisi ESP32
- [ ] Ground bersama: ESP32 + sensor + relay + PSU 12V
- [ ] Built-in LED GPIO 2 tidak diganggu (jika ada)
- [ ] GPIO 0 tidak terhubung ke apa pun
- [ ] Relay module HIGH trigger (bukan LOW trigger)
- [ ] Uji coba: valve ON → air keluar, valve OFF → air berhenti
- [ ] Uji coba: cabut power ESP32 → valve otomatis tertutup
