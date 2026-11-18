# ANDROMEDA — Aplikasi Mobile (Flutter)

Aplikasi Android untuk **ANDROMEDA**, sistem irigasi tetes otomatis berbasis
IoT: pantau kelembaban tanah, kontrol solenoid valve, atur threshold otomatis,
lihat grafik historis, prakiraan cuaca, dan jurnal petani — dengan mode offline.

> Dokumentasi setup end-to-end (Supabase + firmware + aplikasi):
> [`SETUP.md`](../SETUP.md). Panduan rilis: [`release_guide.md`](../release_guide.md).

---

## Prasyarat

- Flutter SDK (lihat `pubspec.yaml` untuk versi Dart minimum).
- Project Supabase aktif dengan schema dari `../database/schema.sql`.
- File `.env` di **root repo** (sumber credential) — lihat `.env.example`.

## Setup Environment

Credential Supabase dibaca dari `.env` via `flutter_dotenv`:

```bash
# 1. Dari root repo: copy template dan isi SUPABASE_URL + SUPABASE_ANON_KEY
cp ../.env.example ../.env

# 2. Sync ke folder ini (wajib sebelum run/build — Flutter membaca
#    .env sebagai asset dari dalam mobile_app/)
cp ../.env .env

# 3. Install dependency dan jalankan
flutter pub get
flutter run
```

Setiap kali mengubah `.env` di root, ulangi langkah sync (no. 2).
`mobile_app/.env` di-ignore git — jangan commit credential asli.

## Mode Mock

Tanpa Supabase, tanpa internet — 6 petak contoh + simulasi ESP32.
Di `.env` root: `APP_DATA_SOURCE=mock`, lalu `cp ../.env .env` + run.
Banner **"MODE MOCK"** menandai data contoh. Detail: [`SETUP.md`](../SETUP.md) §3.3.
Cuaca & jurnal tidak ikut di-mock (cuaca real Open-Meteo, jurnal lokal).

## Perintah Umum

```bash
flutter pub get          # install dependency
flutter analyze          # static analysis (harus bersih)
flutter test             # unit & widget test
flutter run              # debug di emulator/HP
flutter build apk --release       # APK rilis
flutter build appbundle --release # AAB untuk Play Store
```

## Struktur Kode

```
lib/
├── main.dart          ← entry point (load .env, init Supabase, providers)
├── routes.dart        ← definisi rute
├── config/            ← AppConfig (sumber data), SupabaseConfig, theme
├── models/            ← model data (device, sensor, cuaca, jurnal)
├── services/          ← SupabaseService, repository (interface +
│                         implementasi Supabase & mock), cache, cuaca
├── providers/         ← state management (devices, dashboard, cuaca, jurnal, ...)
├── screens/           ← halaman UI
└── widgets/           ← komponen UI reusable
```

## Troubleshooting

| Gejala | Penyebab & Solusi |
|--------|-------------------|
| `Supabase belum dikonfigurasi` saat start | `.env` belum di-sync: `cp ../.env .env`, lalu run ulang |
| Data tidak realtime | Cek koneksi + pastikan Realtime aktif di dashboard Supabase |
| `flutter analyze` gagal | Jalankan `flutter pub get` dulu, perbaiki warning/error yang dilaporkan |
