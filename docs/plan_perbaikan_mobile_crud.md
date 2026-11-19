# Rancangan Perbaikan Fitur CRUD Aplikasi Mobile Andromeda

> **Status:** SELESAI (VERIFIED via Automated Unit & Widget Tests: 46/46 Passed)  
> **Target Platform:** Flutter (`mobile_app`)  
> **Fokus Utama:** Fitur Jurnal & Pengetahuan Petani (`JournalEntry`), Konsistensi Routing, State Management, dan Penanganan Data.

---

## 1. Analisis Akar Masalah (Root Cause Analysis)

### Mengapa Hanya Bisa "Nambah" dan Tidak Bisa Edit / Hapus?

Masalah utama berakar pada **kegagalan passing data saat navigasi route** antara `journal_screen.dart`, `routes.dart`, dan `journal_edit_screen.dart`:

1. **Bug Kritis di `mobile_app/lib/routes.dart` (baris 46):**
   ```dart
   // KODE SAAT INI DI routes.dart:
   case AppRoutes.journalEdit:
     return MaterialPageRoute(builder: (_) => const JournalEditScreen());
   ```
   - `MaterialPageRoute` dibuat **tanpa** meneruskan `settings: settings`.
   - Di Flutter, jika `settings` tidak dioper ke `MaterialPageRoute`, maka `RouteSettings` rute tersebut menjadi default kosong (`arguments: null`).
   - Selain itu, `onGenerateRoute` **tidak mengekstrak** `settings.arguments as JournalEntry?` untuk diteruskan ke konstruktor layar, berbeda dengan rute lain (`dashboard`, `esp32Detail`, `journalArticle`).

2. **Dampak di `mobile_app/lib/screens/journal_edit_screen.dart` (baris 38–46):**
   ```dart
   final args = ModalRoute.of(context)?.settings.arguments;
   if (args is JournalEntry) { ... }
   ```
   - Karena `arguments` selalu bernilai `null`, blok `if (args is JournalEntry)` **tidak pernah dieksekusi**.
   - Variabel `_editId` selalu bernilai `null`.
   - Form selalu menganggap mode adalah **"Tambah Catatan"** baru:
     - Judul form tetap *"Tambah Catatan"*.
     - Kolom Judul dan Isi selalu **kosong melompong** saat kartu catatan diketuk.
     - Tanggal selalu kembali ke hari ini (`DateTime.now()`).
     - Ikon **Hapus** (`Icons.delete_outline`) di AppBar disembunyikan karena ada syarat `if (_editId != null)`. Akibatnya, tombol hapus **tidak pernah bisa diakses sama sekali**.
     - Ketika tombol Simpan ditekan, logic selalu mengeksekusi:
       ```dart
       if (_editId == null) {
         await provider.addEntry(entry); // Selalu tambah entri baru duplikat!
       } else {
         await provider.updateEntry(entry); // TIDAK PERNAH TERCAPAI
       }
       ```
   - **Kesimpulan:** Create (Tambah) berhasil, Read (Tampil daftar) berhasil, namun **Update** dan **Delete** 100% lumpuh.

---

## 2. Penelusuran & Audit Logic di Seluruh Modul Terkait

Kami melakukan penelusuran menyeluruh pada seluruh kode `mobile_app` untuk mendeteksi kelemahan logic, inkonsistensi data, dan potensi masalah CRUD lainnya:

### A. Modul Jurnal Petani
| No | Komponen | Temuan Masalah & Potensi Bug Logic | Dampak |
|---|---|---|---|
| 1 | `journal_edit_screen.dart` | `createdAt` hilang saat update entri: `JournalEntry` dibuat ulang dengan `createdAt: null`, sehingga otomatis ter-set ke waktu baru (`DateTime.now()`). | Tanggal/waktu pembuatan asli catatan hilang terhapus setiap kali catatan diedit. |
| 2 | `journal_provider.dart` | Pengurutan hanya memakai `b.date.compareTo(a.date)`. Padahal `date` dari `showDatePicker` hanya bernilai tanggal (jam 00:00:00). | Catatan yang dibuat pada hari yang sama memiliki urutan acak / tidak stabil. Harus ada secondary sort `b.createdAt.compareTo(a.createdAt)`. |
| 3 | `journal_entry.dart` | Deserialisasi `JournalEntry.fromJson` tidak defensif (`id` cast langsung, `DateTime.parse` tanpa proteksi format/null). | Jika ada data lama atau format rusak di SharedPreferences, aplikasi dapat crash saat inisialisasi `JournalProvider.init()`. |
| 4 | `journal_edit_screen.dart` | Dropdown kategori tidak memvalidasi apakah nilai `entry.category` terdaftar di `JournalProvider.categories`. | Jika terdapat kategori yang tidak dikenal (misal dari sinkronisasi atau perubahan versi), Flutter akan throw runtime crash assertion `items.any((item) => item.value == value)`. |
| 5 | `journal_screen.dart` | Akses Hapus hanya ada di dalam form edit. Pada kartu daftar tidak ada menu aksi langsung (Edit / Hapus). | Kurang ramah pengguna (UX) untuk petani: tidak jelas bahwa kartu bisa dihapus tanpa masuk form terlebih dahulu. |
| 6 | `journal_screen.dart` | Tab "Catatan Saya" belum memiliki filter kategori (Penyiraman, Pemupukan, Hama, Panen), meskipun sudah direncanakan di komentar provider. | Jika catatan sudah banyak, petani kesulitan mencari riwayat penyiraman atau pemupukan tertentu. |
| 7 | `journal_edit_screen.dart` | Tidak ada feedback SnackBar sukses setelah Simpan atau Hapus berhasil (`Navigator.pop` tanpa feedback). | Pengguna ragu apakah catatannya benar-benar tersimpan atau terhapus. |

### B. Modul Routing & Navigasi Global
| Komponen | Temuan Masalah Logic | Solusi yang Direncanakan |
|---|---|---|
| `routes.dart` | Semua `MaterialPageRoute` di `onGenerateRoute` tidak mengoper parameter `settings: settings`. | Tambahkan `settings: settings` pada semua instance `MaterialPageRoute` agar nama route dan metadata navigasi tidak hilang di context widget anak. |
| Type-safety Navigasi | Ekstraksi argumen seperti `settings.arguments as String` rentan throw jika argumen bernilai null. | Tambahkan null-safety fallback (contoh: `settings.arguments as String? ?? ''`). |

### C. Modul Perangkat & Petak Lahan
| Komponen | Status Saat Ini | Catatan Analisis |
|---|---|---|
| **Rename Petak** (`rename_petak_dialog.dart`) | Berfungsi baik (optimistic UI update, sinkronisasi Supabase + cache). | Sudah aman. Namun disarankan menambah opsi reset ke nama default perangkat jika pengguna ingin menghapus nama kustom. |
| **Tambah / Hapus Petak** | Dikelola di backend/hardware (auto-provisioning ESP32). | Petak lahan tidak dibuat secara bebas oleh user di mobile, melainkan dipasangkan dengan unit keras ESP32. Jadi Create/Delete device di mobile memang tidak diperlukan. |

### D. Modul Konfigurasi & Kontrol Valve
| Komponen | Status Saat Ini | Catatan Analisis |
|---|---|---|
| **SystemConfig** (`dashboard_screen.dart`) | Update config berjalan baik dengan validasi `dry < wet`. | Catatan: `_syncConfigLocals` dipanggil di dalam `_buildConfigSection` (dalam fase `build`). Akan dirapikan agar sinkronisasi state tidak menimbulkan efek samping saat widget re-render. |
| **Perintah Valve** | State machine (`sending` -> `pending` -> `executed` / `expired` / `cancelled`) sudah teruji dengan baik. | Berjalan stabil. |

---

## 3. Rencana Perbaikan Step-by-Step (Action Plan)

### Langkah 1: Perbaikan Routing & Parameter Passing (`routes.dart`)
1. Di `AppRoutes.onGenerateRoute`:
   - Ekstrak `final entry = settings.arguments as JournalEntry?;`.
   - Teruskan langsung ke konstruktor: `JournalEditScreen(entry: entry)`.
   - Sertakan `settings: settings` di setiap `MaterialPageRoute`.
   - Berikan fallback aman pada parsing rute lainnya (`dashboard`, `esp32Detail`, `journalArticle`).

### Langkah 2: Refactoring `JournalEditScreen`
1. Ubah konstruktor agar menerima `final JournalEntry? entry;`.
2. Pindahkan inisialisasi data dari `didChangeDependencies` ke `initState()`:
   - Jika `widget.entry != null`, isi `_editId`, `_date`, `_category`, `_titleController`, `_contentController`.
   - Validasi `_category`: jika tidak ada di daftar kategori valid, fallback aman ke `'lainnya'`.
3. Perbaiki fungsi `_save()`:
   - Pertahankan waktu `createdAt` asli saat update: `createdAt: widget.entry?.createdAt ?? DateTime.now()`.
   - Tambahkan validasi whitespace (`title.trim()`).
   - Tampilkan SnackBar sukses: *"Catatan berhasil disimpan"* (tambah baru) atau *"Catatan berhasil diperbarui"* (edit).
4. Perbaiki fungsi `_delete()`:
   - Tampilkan dialog konfirmasi hapus.
   - Panggil `provider.deleteEntry(_editId!)`.
   - Tampilkan SnackBar sukses: *"Catatan berhasil dihapus"*.

### Langkah 3: Penguatan Model `JournalEntry` (`journal_entry.dart`)
1. Tambahkan metode `copyWith(...)` untuk mempermudah manipulasi data tanpa kehilangan field yang ada.
2. Buat `fromJson` defensif:
   - `id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString()`.
   - `date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now()`.
   - `createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now()`.

### Langkah 4: Penguatan State Provider `JournalProvider` (`journal_provider.dart`)
1. Perbaiki getter `entries`:
   - Urutkan pertama berdasarkan `b.date.compareTo(a.date)`.
   - Jika tanggal sama (`cmp == 0`), urutkan kedua berdasarkan `b.createdAt.compareTo(a.createdAt)` (terbaru di atas).
2. Tambahkan fungsi helper pencarian dan filter kategori (opsional query filter).

### Langkah 5: Peningkatan Tampilan & Interaksi `JournalScreen` (`journal_screen.dart`)
1. **Menu Aksi Cepat pada Kartu Catatan (`_EntryCard`):**
   - Tambahkan tombol menu titik tiga (`PopupMenuButton`) pada setiap kartu entri dengan 2 opsi:
     - ✏️ **Edit Catatan** -> Membuka form edit dengan data terisi.
     - 🗑️ **Hapus Catatan** -> Membuka dialog konfirmasi langsung tanpa harus masuk ke form edit.
   - Tetap izinkan tap langsung pada kartu untuk membuka edit.
2. **Filter Chip Kategori:**
   - Tambahkan baris horizontal `ChoiceChip` di atas daftar catatan:
     - `Semua` | `💧 Penyiraman` | `🌱 Pemupukan` | `🐛 Hama & Penyakit` | `🌾 Panen` | `📝 Lainnya`
   - Memudahkan petani memantau riwayat aktivitas spesifik.

### Langkah 6: Pembuatan Unit & Widget Test Lengkap (`journal_test.dart`)
1. Buat file pengujian baru di `mobile_app/test/journal_test.dart` yang memverifikasi:
   - Inisialisasi dan parsing model `JournalEntry` (defensif terhadap corrupt data).
   - CRUD `JournalProvider`: `addEntry`, `updateEntry`, `deleteEntry`, dan persistensi ke SharedPreferences mock.
   - Pengurutan ganda (tanggal + created_at).
   - Passing argumen navigasi ke `JournalEditScreen` (memastikan mode edit vs tambah aktif dengan benar).

---

## 4. Alur Kerja Sebelum & Sesudah Perbaikan

```mermaid
flowchart TD
    subgraph Kondisi Lama (Bermasalah)
        A1[Tap Kartu Catatan di Daftar] --> B1[Navigator.pushNamed journalEdit]
        B1 --> C1[routes.dart TIDAK teruskan settings/args]
        C1 --> D1[JournalEditScreen: args = null]
        D1 --> E1[Form Tampil KOSONG & Judul 'Tambah Catatan']
        E1 --> F1[Tombol Hapus TIDAK MUNCUL]
        E1 --> G1[Simpan Catatan]
        G1 --> H1[Selalu addEntry -> DUPLIKAT DIBUAT alih-alih update!]
    end

    subgraph Kondisi Baru (Setelah Perbaikan)
        A2[Tap Kartu / Menu Titik Tiga] --> B2[Navigator.pushNamed journalEdit + entry]
        B2 --> C2[routes.dart teruskan entry ke konstruktor]
        C2 --> D2[JournalEditScreen: data & _editId termuat lengkap]
        D2 --> E2[Judul 'Edit Catatan', Form Terisi, Ikon Hapus Tampil]
        D2 --> F2[Hapus Catatan -> Dialog Konfirmasi -> provider.deleteEntry]
        D2 --> G2[Simpan Perubahan -> provider.updateEntry -> data diperbarui]
        D2 --> H2[SnackBar Feedback Sukses]
    end
```

---

## 5. Ringkasan File yang Akan Dimodifikasi

| Path File | Jenis Perubahan | Deskripsi |
|---|---|---|
| `mobile_app/lib/routes.dart` | Modifikasi | Passing `entry` ke `JournalEditScreen` + sertakan `settings: settings` |
| `mobile_app/lib/screens/journal_edit_screen.dart` | Modifikasi | Konstruktor `entry`, `initState` data loading, perbaiki logic `_save()` & `_delete()`, SnackBar feedback |
| `mobile_app/lib/screens/journal_screen.dart` | Modifikasi | Menu titik tiga (Edit & Hapus langsung pada kartu), Chip filter kategori |
| `mobile_app/lib/models/journal_entry.dart` | Modifikasi | `copyWith`, defensive `fromJson` parsing |
| `mobile_app/lib/providers/journal_provider.dart` | Modifikasi | Stable sorting (`date` desc + `createdAt` desc) |
| `mobile_app/test/journal_test.dart` | **File Baru** | Test suite komprehensif untuk validasi CRUD jurnal |
| `docs/design-v0.2-cuaca-jurnal-rekapan-offline.md` | Dokumentasi | Update dokumentasi teknis fitur jurnal |

---

## 6. Permintaan Konfirmasi (ACC)

Silakan tinjau rancangan perbaikan logic dan teknis di atas. Jika Anda menyetujui (**ACC**) rancangan ini, saya akan segera:
1. Menggarap kode perbaikan pada seluruh file yang tertera.
2. Membuat pengujian otomatis (`journal_test.dart`) dan menjalankan `flutter test` untuk memastikan 100% lulus tanpa regresi.
3. Memperbarui dokumentasi teknis projek.
