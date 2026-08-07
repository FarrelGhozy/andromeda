# Release Guide — ANDROMEDA

> **WAJIB DIBACA OLEH AI AGENT / DEVELOPER SEBELUM MELAKUKAN RELEASE.**
> Ikuti pedoman di file ini. Jangan release di luar aturan yang tertulis di sini.

---

## 1. Skema Versi: Semantic Versioning

Versi menggunakan **Semantic Versioning** (`MAJOR.MINOR.PATCH`) di dalam
`mobile_app/pubspec.yaml` (field `version`, format `MAJOR.MINOR.PATCH+build`):

```
MAJOR.MINOR.PATCH + buildNumber
```

Aturan kapan naik (SemVer standar):

- **MAJOR** — perubahan tidak kompatibel (breaking), reset UI besar, atau rilis 1.0 formal.
  Contoh: `0.x.y` → `1.0.0`.
- **MINOR** — fitur baru yang tetap backward-compatible.
  Contoh: `0.1.0` → `0.2.0`.
- **PATCH** — perbaikan bug, fix kecil, polish; tidak menambah fitur.
  Contoh: `0.1.0` → `0.1.1`.

`buildNumber` (bagian setelah `+`) **selalu naik +1 pada setiap build**, apa pun
jenis kenaikannya. Ini wajib, karena Android butuh `versionCode` unik per build.

### Contoh ritme rilis
| Versi  | Jenis Perubahan | Nama Rilis |
|--------|-----------------|------------|
| 0.1.0  | rilis awal      | BIMA       |
| 0.1.1  | fix bug         | BIMA       |
| 0.2.0  | fitur baru      | GATOTKACA  |
| 0.3.0  | fitur baru      | ARJUNA     |
| 1.0.0  | major / breaking| SEMAR     |

---

## 2. Nama Rilis (Codename): Tokoh Wayang

Setiap rilis punya **codename tokoh wayang**. **Nama rilis hanya berubah pada
perubahan MAJOR atau MINOR.** Perubahan PATCH **tidak mengganti nama** — versinya
beda, tapi nama wayang tetap sama.

### Daftar nama wayang (berurutan, dipakai bergantian)

Mulai dari `BIMA`. Setiap naik **MINOR atau MAJOR**, lanjut ke nama berikutnya
dalam daftar. Ketika daftar habis, diskusikan bersama sebelum menentukan lanjutan.

1. BIMA
2. GATOTKACA
3. ARJUNA
4. NAKULA
5. SADEWA
6. YUDISTIRA
7. KRESNA
8. SEMAR
9. PETRUK
10. GARENG
11. BAGONG
12. ABIMANYU
13. SRIKANDI
14. ANTA

### Aturan nama
- **PATCH naik → nama tetap sama.** Contoh: `0.1.0 - BIMA`, lalu `0.1.1` juga tetap **BIMA**, `0.1.2` tetap **BIMA**.
- **MINOR naik → nama lanjut.** `0.1.1 - BIMA` → `0.2.0 - GATOTKACA`.
- **MAJOR naik → nama lanjut.** `0.3.0 - ARJUNA` → `1.0.0 - SEMAR`.

---

## 3. Alur Release (Wajib Diikuti)

### A. Menentukan versi baru
1. Baca riwayat commit / label perubahan (`feat` / `fix` / `breaking`) untuk
   menentukan naik MAJOR / MINOR / PATCH.
2. Tentukan nomor versi + codename (lihat §1 & §2).

### B. Menyiapkan kode sebelum rilis
1. Buka `mobile_app/pubspec.yaml`, pastikan `version` sudah benar
   (`MAJOR.MINOR.PATCH+build`), mis. `0.1.0+1`.
2. Jalankan dari folder `mobile_app/`:
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   ```
   Harus lulus semua sebelum lanjut.

### C. Membangun artefak
Buat **release APK** untuk distribusi manual / test HP:

```bash
flutter build apk --release
```

Hasil: `mobile_app/build/app/outputs/flutter-apk/app-release.apk`.

Untuk Play Store, gunakan:

```bash
flutter build appbundle --release
```

Hasil: `mobile_app/build/app/outputs/bundle/release/app-release.aab`.

### D. Menguji
Jalankan `app-release.apk` di HP fisik. Pastikan: splash → dashboard → ESP32 →
petak → valve berfungsi; tanpa crash; log tanpa `GeneratedPluginRegistrant`
(plugin ke-register dengan benar).

### E. Commit + tag + push
```bash
git add -A
git commit -m "release(android): 0.1.0 - BIMA <ringkasan>"
git tag -a v0.1.0-BIMA -m "release 0.1.0 - BIMA"
git push origin main --tags
```

**Aturan tag:** prefiks `v`, diikuti `MAJOR.MINOR.PATCH`, lalu `-` + codename.
Contoh: `v0.1.0-BIMA`, `v0.2.0-GATOTKACA`.

---

## 4. Tentang Signing

- Saat ini `mobile_app/android/app/build.gradle.kts` men-sign release dengan
  **debug keystore** (`signingConfigs.getByName("debug")`). Valid untuk
  distribusi ke teman/pengujian, **tidak valid** untuk Play Store.
- Kalau mau publikasi Play Store: buat **release keystore**, atur
  `key.properties`, dan ganti signing config release. **Jangan commit
  keystore maupun password** ke repo (tambahkan ke `.gitignore`).

---

## 5. Rilis Firmware (ESP32)

Firmware (`hardware/firmware`) **ikut skema versi & ritme rilis yang sama**
dengan mobile app (§1–§2): SemVer yang sama, codename wayang yang sama, dan tag
release yang **satu**. Satu ritme rilis untuk seluruh proyek ANDROMEDA.

### Artefak yang direproduksi

Release firmware = binary yang bisa di-flash ulang: `hardware/firmware/.pio/
build/esp32dev/firmware.bin`. Untuk reproducible, **dependency sudah di-pin**
di `hardware/firmware/platformio.ini` (platform `espressif32@7.0.1`,
`ArduinoJson@6.21.3`), jadi build di mesin mana pun menghasilkan artefak yang
sama versinya.

### Membangun & menguji

Dari `hardware/firmware/`:

```bash
make build      # kompilasi deterministic
make test       # host unit tests
make monitor    # serial monitor 115200
```

Tanpa Makefile (sama saja): `pio run`, `pio test`, `pio device monitor`.

> **Catatan:** `make` butuh lingkungan Unix (macOS/Linux, atau Git Bash di
> Windows), dan `pio` harus ada di `PATH`. Kalau tidak ada, gunakan perintah
> `pio` langsung.

### Flashing ke perangkat

```bash
make upload   # = pio run -e esp32dev -t upload
```

Device di-flash ke **esp32-01** dan **esp32-02** (pinout identik; yang beda
hanya device ID di `include/devices/`). Pastikan dua-duanya diberi binary yang
sama.

### Alur rilis firmware

1. Tentukan versi **sama dengan release mobile app** (§1–§2). Contoh: rilis
   `V0.1.0 - BIMA` mencakup APK **dan** firmware.
2. Bump `platformio.ini` kalau ada perubahan toolchain (dan naikkan versi
   sesuai SemVer).
3. `make test` lulus, lalu `make build`.
4. Flash hasilnya ke esp32-01 & esp32-02, uji di lapangan (valve ON/OFF,
   sensor ter-baca, valve NC menutup saat power mati).
5. Satu tag untuk kedua artefak (lihat §3.E): `git tag -a <versi>-<NAMA>`.

---

## 6. Checklist Akhir (tanda ✓ semua)

- [ ] Version naik sesuai rule SemVer (§1)
- [ ] buildNumber (`+N`) naik dari versi sebelumnya
- [ ] Codename benar: berubah saat MIN/MAJ, tetap saat PATCH (§2)
- [ ] `flutter pub get`, `analyze`, `test` lulus
- [ ] `flutter build apk --release` sukses
- [ ] Artefak dites di HP fisik
- [ ] Commit + tag `v<versi>-<NAMA>` + push `--tags`

### Firmware (bila ikut dalam rilis ini)
- [ ] `platformio.ini` dependency ter-pin (platform & lib) (§5)
- [ ] `make test` + `make build` sukses
- [ ] Binary di-flash ke esp32-01 & esp32-02 dan teruji

---

> Jika ragu tentang aturan di atas, tanya ke pemilik proyek sebelum lanjut.
> Jangan buat keputusan versi/nama sendiri di luar pedoman ini.
