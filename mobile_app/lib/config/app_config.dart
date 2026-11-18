// ============================================================
// SUMBER DATA APLIKASI — dibaca dari file .env
// ============================================================
// APP_DATA_SOURCE:
// - "supabase" (default) → data live dari Supabase (butuh URL + key,
//   butuh internet). Dipakai di kebun / produksi.
// - "mock"              → data contoh lokal, tanpa Supabase, tanpa
//   internet. Dipakai untuk development, demo, dan screenshot.
//   Tombol-tombol tetap memberi feedback (SnackBar) seperti biasa,
//   tapi tidak ada efek ke dunia nyata.
// ============================================================
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppDataSource { supabase, mock }

class AppConfig {
  static AppDataSource get dataSource {
    final raw = (dotenv.env['APP_DATA_SOURCE'] ?? '').trim().toLowerCase();
    return raw == 'mock' ? AppDataSource.mock : AppDataSource.supabase;
  }

  static bool get isMockMode => dataSource == AppDataSource.mock;
}
