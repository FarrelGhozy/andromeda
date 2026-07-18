import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_config.dart';

class ConfigRepository {
  final SupabaseClient _client;

  ConfigRepository(this._client);

  /// Stream konfigurasi 1 petak (realtime)
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

  /// Ambil config sekali
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

  /// Update config
  Future<void> updateConfig(String deviceId, SystemConfig config) async {
    await _client.from('system_config').update(config.toJson()).eq(
        'device_id', deviceId);
  }
}
