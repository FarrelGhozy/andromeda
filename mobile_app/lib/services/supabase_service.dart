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
      anonKey: SupabaseConfig.anonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        heartbeatInterval: Duration(seconds: 10),
      ),
    );
  }

  /// Cek koneksi Supabase — ambil 1 baris dari devices
  Future<bool> checkConnection() async {
    try {
      final response = await client.from('devices').select().limit(1);
      return response != null;
    } catch (_) {
      return false;
    }
  }
}
