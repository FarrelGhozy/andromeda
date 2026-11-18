// ============================================================
// KONFIGURASI SUPABASE — dibaca dari file .env
// ============================================================
// Setup:
// 1. Copy `.env.example` menjadi `.env` di ROOT projek/
// 2. Isi SUPABASE_URL dan SUPABASE_ANON_KEY dari dashboard Supabase
//    (Project Settings → API)
// 3. Sync ke folder mobile sebelum jalanin Flutter:
//      cp .env mobile_app/.env
// 4. Pastikan `dotenv.load()` sudah dipanggil di main() sebelum
//    Supabase di-init.
// ============================================================
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url =>
      dotenv.env['SUPABASE_URL'] ?? '';

  static String get publishableKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// True kalau .env sudah ke-load dan terisi dengan benar.
  static bool get isConfigured =>
      url.isNotEmpty && publishableKey.isNotEmpty;
}
