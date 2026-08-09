import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sensor_reading.dart';
import '../models/pending_command.dart';

class SensorRepository {
  final SupabaseClient _client;

  SensorRepository(this._client);

  /// Stream data sensor terbaru untuk 1 petak
  Stream<SensorReading?> getLatestSensorStream(String deviceId) {
    return _client
        .from('sensor_readings')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(1)
        .map((list) => list.isNotEmpty
            ? SensorReading.fromJson(list.first)
            : null);
  }

  /// Stream data sensor historis (untuk chart)
  Stream<List<SensorReading>> getSensorHistoryStream(String deviceId,
      {int limit = 100}) {
    return _client
        .from('sensor_readings')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((list) =>
            list.map((m) => SensorReading.fromJson(m)).toList());
  }

  /// Ambil data historis untuk chart
  Future<List<SensorReading>> getHistory({
    required String deviceId,
    required DateTime since,
    required DateTime until,
  }) async {
    final response = await _client
        .from('sensor_readings')
        .select()
        .eq('device_id', deviceId)
        .gte('created_at', since.toIso8601String())
        .lte('created_at', until.toIso8601String())
        .order('created_at');
    return (response as List)
        .map((e) => SensorReading.fromJson(e))
        .toList();
  }

  /// Kirim perintah valve
  Future<void> sendCommand({
    required String deviceId,
    required String command,
    int duration = 30,
    String source = 'android',
  }) async {
    await _client.from('pending_commands').insert({
      'device_id': deviceId,
      'command': command,
      'duration': duration,
      'status': 'pending',
      'source': source,
    });
  }

  /// Stream command TERBARU untuk 1 petak (fix #18: pantau eksekusi
  /// ESP32 → status pending → executed/expired/cancelled).
  Stream<PendingCommand?> getLatestCommandStream(String deviceId) {
    return _client
        .from('pending_commands')
        .stream(primaryKey: ['id'])
        .eq('device_id', deviceId)
        .order('id', ascending: false)
        .limit(1)
        .map((list) => list.isNotEmpty
            ? PendingCommand.fromJson(list.first)
            : null);
  }

  /// Ubah status command (expired / cancelled) dari app (fix #20).
  Future<void> updateCommandStatus(int commandId, String status) async {
    await _client
        .from('pending_commands')
        .update({'status': status})
        .eq('id', commandId);
  }

  /// Tandai semua command pending yang basi (> olderThan) sebagai expired
  /// (fix #20 — command basi tidak boleh "menyalakan" valve di kemudian
  /// hari saat ESP32 tiba-tiba online).
  Future<void> expireStaleCommands(String deviceId, DateTime olderThan) async {
    await _client
        .from('pending_commands')
        .update({'status': 'expired'})
        .eq('device_id', deviceId)
        .eq('status', 'pending')
        .lt('created_at', olderThan.toIso8601String());
  }
}
