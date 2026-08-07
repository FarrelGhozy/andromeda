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

## 5. Checklist Akhir (tanda ✓ semua)

- [ ] Version naik sesuai rule SemVer (§1)
- [ ] buildNumber (`+N`) naik dari versi sebelumnya
- [ ] Codename benar: berubah saat MIN/MAJ, tetap saat PATCH (§2)
- [ ] `flutter pub get`, `analyze`, `test` lulus
- [ ] `flutter build apk --release` sukses
- [ ] Artefak dites di HP fisik
- [ ] Commit + tag `v<versi>-<NAMA>` + push `--tags`

---

> Jika ragu tentang aturan di atas, tanya ke pemilik proyek sebelum lanjut.
> Jangan buat keputusan versi/nama sendiri di luar pedoman ini.
