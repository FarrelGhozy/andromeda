# 🚀 ANDROMEDA

**A**ndroid **R**outine **M**onitoring **E**lectronic **D**rip **A**utomation

Sistem Irigasi Tetes Otomatis Berbasis IoT — Monitoring & Kontrol Android
Program PDB (Program Desa Binaan) — **Desa Merayan**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
![Platform](https://img.shields.io/badge/Platform-ESP32-blue)
![Backend](https://img.shields.io/badge/Backend-Supabase-orange)
![Mobile](https://img.shields.io/badge/Mobile-Flutter-02569B)

---

## 🌾 Tentang

**ANDROMEDA** mengotomatiskan irigasi tetes untuk petani di **Desa Merayan** — sensor kelembaban tanah dibaca **ESP32**, data dikirim ke **Supabase**, dan petani memantau/mengontrol dari **HP Android** kapan aja. Tenaga dari **aki 100Ah + solar panel 300Wp**, internet dari **router 4G LTE** (Rp 15.000/bulan), air mengalir dari **tandon + solenoid valve** tanpa pompa.

### Fitur Utama
- 📊 **Dashboard real-time** — kelembaban tanah + status valve per petak
- 🔓 **Kontrol valve manual** — buka/tutup dari HP
- 🤖 **Mode otomatis** — siram saat kering, berhenti saat basah
- ⚙️ **Atur threshold** — batas kering/basah sesuai tanaman
- 📈 **Grafik historis** — riwayat kelembaban
- 🟢 **Status online/offline** akurat via heartbeat ESP32

---

## 📚 Dokumentasi

| Topik | Dokumen |
|-------|---------|
| 🚀 **Setup cepat** (Supabase + firmware + app) | [SETUP.md](SETUP.md) |
| 📋 **Perencanaan detail & roadmap** | [docs/blueprint-andromeda.md](docs/blueprint-andromeda.md) |
| 🧠 **Arsitektur ESP32** (state machine, daya, kalibrasi) | [docs/architecture-esp32.md](docs/architecture-esp32.md) |
| 📱 **Rancangan aplikasi Flutter** | [docs/blueprint-flutter-app.md](docs/blueprint-flutter-app.md) |
| 🔌 **Pinout & wiring** | [hardware/pinout-wiring.md](hardware/pinout-wiring.md) |
| 🛒 **Daftar belanja (BOM)** | [hardware/belanja.md](hardware/belanja.md) |
| 🗄️ **Schema database (SQL)** | [database/schema.sql](database/schema.sql) |
| 🏷️ **Panduan release** (SemVer + codename) | [release_guide.md](release_guide.md) |

---

## 🏗️ Arsitektur Singkat

```
Solar Panel 300Wp → Aki 100Ah → Router 4G LTE ──► ESP32 ──► Solenoid Valve
                                              │        ▲
                                              ▼        │
                                        Supabase (PostgreSQL + Realtime)
                                              ▲        │
                                              └── Flutter App (Android)
```

> Detail lengkap: [blueprint-andromeda.md](docs/blueprint-andromeda.md) & [architecture-esp32.md](docs/architecture-esp32.md)

---

## 📁 Struktur Repo

```
andromeda/
├── database/       ← PostgreSQL schema + RLS + seed (schema.sql)
├── hardware/
│   ├── firmware/   ← PlatformIO project ESP32 (C/C++)
│   ├── belanja.md  ← Bill of Materials
│   └── pinout-wiring.md
├── mobile_app/     ← Flutter app (Android)
└── docs/           ← Blueprint, arsitektur, rancangan, proposal
```

---

## 👨‍💻 Tim

| Peran | Nama |
|-------|------|
| **Ketua / Pengembang** | Farrel Ghozy Afifudin (452024611053) |
| **Pengembang** | Fatih Jawwad |
| **Dosen Pembimbing** | ... |

**Prodi:** Teknik Informatika — UNIDA Gontor
**Program:** PDB (Program Desa Binaan) — **Desa Merayan**

---

## 📄 Lisensi

MIT License — silakan dikembangkan untuk desa lain.

## 📞 Kontak

**Farrel Ghozy Afifudin** — farrelafif05@gmail.com — [github.com/FarrelGhozy](https://github.com/FarrelGhozy)

---

> 🌾 *ANDROMEDA — Dari petani, oleh petani, untuk petani.*
