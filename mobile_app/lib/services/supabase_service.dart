import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  Future<void> init() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publishableKey,
    );
  }

  /// Cek koneksi Supabase
  Future<bool> checkConnection() async {
    try {
      final response = await client.from('devices').select().limit(1);
      return true;
    } catch (_) {
      return false;
    }
  }
}
