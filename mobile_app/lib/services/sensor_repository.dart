import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sensor_reading.dart';
import '../models/pending_command.dart';

/// Sumber data sensor + perintah valve.
///
/// Implementasi ada dua:
/// - [SupabaseSensorRepository] → data live dari Supabase.
/// - Mock (lihat `services/mock/`) → data contoh lokal (mode mock).
abstract interface class SensorRepository {
  /// Ambil reading terbaru 1 petak sekali (fallback realtime).
  Future<SensorReading?> getLatestReading(String deviceId);

  /// Stream data sensor terbaru untuk 1 petak
  Stream<SensorReading?> getLatestSensorStream(String deviceId);

  /// Stream data sensor historis (untuk chart)
  Stream<List<SensorReading>> getSensorHistoryStream(String deviceId,
      {int limit = 100});

  /// Ambil data historis untuk chart
  Future<List<SensorReading>> getHistory({
    required String deviceId,
    required DateTime since,
    required DateTime until,
  });

  /// Kirim perintah valve
  Future<void> sendCommand({
    required String deviceId,
    required String command,
    int duration = 30,
    String source = 'android',
  });

  /// Stream command TERBARU untuk 1 petak (fix #18: pantau eksekusi
  /// ESP32 → status pending → executed/expired/cancelled).
  Stream<PendingCommand?> getLatestCommandStream(String deviceId);

  /// Ubah status command (expired / cancelled) dari app (fix #20).
  Future<void> updateCommandStatus(int commandId, String status);

  /// Tandai semua command pending yang basi (> olderThan) sebagai expired
  /// (fix #20 — command basi tidak boleh "menyalakan" valve di kemudian
  /// hari saat ESP32 tiba-tiba online).
  Future<void> expireStaleCommands(String deviceId, DateTime olderThan);
}

class SupabaseSensorRepository implements SensorRepository {
  final SupabaseClient _client;

  SupabaseSensorRepository(this._client);

  @override
  Future<SensorReading?> getLatestReading(String deviceId) async {
    final response = await _client
        .from('sensor_readings')
        .select()
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = response as List;
    return list.isNotEmpty ? SensorReading.fromJson(list.first) : null;
  }

  @override
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

  @override
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

  @override
  Future<List<SensorReading>> getHistory({
    required String deviceId,
    required DateTime since,
    required DateTime until,
  }) async {
    // Fix #32: kirim dalam UTC — PostgREST mengartikan string tanpa
    // offset sebagai UTC, padahal DateTime.now() lokal (WIB) → window
    // bergeser 7 jam jika tidak dikonversi.
    final response = await _client
        .from('sensor_readings')
        .select()
        .eq('device_id', deviceId)
        .gte('created_at', since.toUtc().toIso8601String())
        .lte('created_at', until.toUtc().toIso8601String())
        .order('created_at');
    return (response as List)
        .map((e) => SensorReading.fromJson(e))
        .toList();
  }

  @override
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

  @override
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

  @override
  Future<void> updateCommandStatus(int commandId, String status) async {
    await _client
        .from('pending_commands')
        .update({'status': status})
        .eq('id', commandId);
  }

  @override
  Future<void> expireStaleCommands(
      String deviceId, DateTime olderThan) async {
    await _client
        .from('pending_commands')
        .update({'status': 'expired'})
        .eq('device_id', deviceId)
        .eq('status', 'pending')
        .lt('created_at', olderThan.toUtc().toIso8601String());
  }
}
