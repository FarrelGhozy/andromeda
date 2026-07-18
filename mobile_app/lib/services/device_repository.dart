import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';
import '../models/sensor_reading.dart';

class DeviceRepository {
  final SupabaseClient _client;

  DeviceRepository(this._client);

  /// Stream daftar semua device (realtime)
  Stream<List<Device>> getDevicesStream() {
    return _client
        .from('devices')
        .stream(primaryKey: ['id'])
        .order('id')
        .map((maps) => maps.map((m) => Device.fromJson(m)).toList());
  }

  /// Ambil 1 device
  Future<Device?> getDevice(String deviceId) async {
    try {
      final response = await _client
          .from('devices')
          .select()
          .eq('device_id', deviceId)
          .single();
      return Device.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  /// Ambil data terbaru untuk semua petak (via RPC)
  Future<Map<String, SensorReading?>> getLatestReadings() async {
    try {
      final response = await _client.rpc('get_latest_readings');
      final list = response as List;
      return {
        for (var item in list)
          item['device_id'] as String: SensorReading.fromJson(item),
      };
    } catch (_) {
      return {};
    }
  }
}
