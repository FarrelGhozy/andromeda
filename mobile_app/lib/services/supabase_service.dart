import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device.dart';
import '../models/reading.dart';
import '../models/config.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<List<Device>> fetchDevices() async {
    final response = await client.from('devices').select().order('device_id');
    return (response as List).map((e) => Device.fromMap(e)).toList();
  }

  static Future<Reading?> fetchLatestReadingForDevice(String deviceId) async {
    final response = await client
        .from('sensor_readings')
        .select()
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(1);
    final list = response as List;
    if (list.isEmpty) return null;
    return Reading.fromMap(list.first);
  }

  static Future<List<Reading>> fetchReadingsForDevice(
    String deviceId, {
    int limit = 24,
  }) async {
    final response = await client
        .from('sensor_readings')
        .select()
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (response as List).map((e) => Reading.fromMap(e)).toList();
  }

  static Future<DeviceConfig?> fetchConfig(String deviceId) async {
    final response = await client
        .from('system_config')
        .select()
        .eq('device_id', deviceId)
        .limit(1);
    final list = response as List;
    if (list.isEmpty) return null;
    return DeviceConfig.fromMap(list.first);
  }

  static Future<void> updateConfig(DeviceConfig config) async {
    await client
        .from('system_config')
        .update(config.toMap())
        .eq('device_id', config.deviceId);
  }

  static Future<void> sendCommand(
    String deviceId,
    String command, {
    int duration = 30,
  }) async {
    await client.from('pending_commands').insert({
      'device_id': deviceId,
      'command': command,
      'duration': duration,
      'status': 'pending',
      'source': 'mobile_app',
    });
  }

  static Stream<List<Map<String, dynamic>>> sensorReadingsStream() {
    return client
        .from('sensor_readings')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> systemConfigStream() {
    return client.from('system_config').stream(primaryKey: ['id']);
  }
}
