import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';
import '../models/sensor_reading.dart';

class DeviceRepository {
  final SupabaseClient _client;

  DeviceRepository(this._client);

  /// Stream daftar device AKTIF saja (realtime).
  /// Petak tanpa sensor (status 'inactive') tidak ditampilkan —
  /// sinkron dengan kenyataan hardware & data di Supabase.
  Stream<List<Device>> getDevicesStream() {
    return _client
        .from('devices')
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .order('id')
        .map((maps) => maps.map((m) => Device.fromJson(m)).toList());
  }

  /// Ambil daftar device AKTIF sekali (tanpa realtime)
  Future<List<Device>> getDevices() async {
    final response = await _client
        .from('devices')
        .select()
        .eq('status', 'active')
        .order('id');
    return (response as List).map((m) => Device.fromJson(m)).toList();
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

  /// Stream realtime: tiap INSERT/UPDATE pada sensor_readings.
  /// Dipakai agar list petak & detail selalu sinkron dengan data terbaru.
  Stream<SensorReading> readingsLiveStream() {
    final controller = StreamController<SensorReading>.broadcast();
    final channel = _client.channel('sensor_readings_live');
    void handle(PostgresChangePayload payload) {
      if (payload.newRecord.isEmpty) return;
      controller.add(SensorReading.fromJson(payload.newRecord));
    }

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sensor_readings',
          callback: handle,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'sensor_readings',
          callback: handle,
        )
        .subscribe();
    controller.onCancel = () {
      channel.unsubscribe();
      controller.close();
    };
    return controller.stream;
  }
}
