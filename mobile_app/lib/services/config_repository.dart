import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_config.dart';

/// Sumber konfigurasi petak.
///
/// Implementasi ada dua:
/// - [SupabaseConfigRepository] → data live dari Supabase.
/// - Mock (lihat `services/mock/`) → data contoh lokal (mode mock).
abstract interface class ConfigRepository {
  /// Stream konfigurasi 1 petak (realtime)
  Stream<SystemConfig?> getConfigStream(String deviceId);

  /// Ambil config sekali
  Future<SystemConfig?> getConfig(String deviceId);

  /// Update config
  Future<void> updateConfig(String deviceId, SystemConfig config);
}

class SupabaseConfigRepository implements ConfigRepository {
  final SupabaseClient _client;

  SupabaseConfigRepository(this._client);

  @override
  Stream<SystemConfig?> getConfigStream(String deviceId) {
    return _client
        .from('system_config')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .limit(1)
        .map((list) => list.isNotEmpty
            ? SystemConfig.fromJson(list.first)
            : null);
  }

  @override
  Future<SystemConfig?> getConfig(String deviceId) async {
    try {
      final response = await _client
          .from('system_config')
          .select()
          .eq('device_id', deviceId)
          .single();
      return SystemConfig.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> updateConfig(String deviceId, SystemConfig config) async {
    await _client.from('system_config').update(config.toJson()).eq(
        'device_id', deviceId);
  }
}
