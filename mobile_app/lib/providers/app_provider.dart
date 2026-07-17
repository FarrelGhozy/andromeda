import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/reading.dart';
import '../models/config.dart';
import '../services/supabase_service.dart';

class AppProvider extends ChangeNotifier {
  List<Device> devices = [];
  Map<String, Reading> latestReadings = {};
  Map<String, DeviceConfig> configs = {};
  bool loading = true;

  AppProvider() {
    init();
  }

  Future<void> init() async {
    loading = true;
    notifyListeners();
    await fetchDevices();
    await fetchAllData();
    loading = false;
    notifyListeners();
    subscribeToRealtime();
  }

  Future<void> fetchDevices() async {
    devices = await SupabaseService.fetchDevices();
    notifyListeners();
  }

  Future<void> fetchAllData() async {
    for (final device in devices) {
      final reading = await SupabaseService.fetchLatestReadingForDevice(device.deviceId);
      if (reading != null) {
        latestReadings[device.deviceId] = reading;
      }
      final config = await SupabaseService.fetchConfig(device.deviceId);
      if (config != null) {
        configs[device.deviceId] = config;
      }
    }
    notifyListeners();
  }

  void subscribeToRealtime() {
    SupabaseService.sensorReadingsStream().listen((data) {
      for (final row in data) {
        final reading = Reading.fromMap(row);
        latestReadings[reading.deviceId] = reading;
      }
      notifyListeners();
    });

    SupabaseService.systemConfigStream().listen((data) {
      for (final row in data) {
        final config = DeviceConfig.fromMap(row);
        configs[config.deviceId] = config;
      }
      notifyListeners();
    });
  }

  Future<void> refresh() async {
    await fetchAllData();
  }

  Future<void> sendCommand(String deviceId, String command, {int duration = 30}) async {
    await SupabaseService.sendCommand(deviceId, command, duration: duration);
  }

  Future<void> updateConfig(DeviceConfig config) async {
    await SupabaseService.updateConfig(config);
    configs[config.deviceId] = config;
    notifyListeners();
  }
}
