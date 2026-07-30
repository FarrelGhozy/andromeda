import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/sensor_reading.dart';
import '../services/device_repository.dart';

class DevicesProvider extends ChangeNotifier {
  final DeviceRepository _deviceRepo;

  List<Device> _devices = [];
  Map<String, SensorReading?> _latestReadings = {};
  bool _isLoading = true;
  bool _readingsLoaded = false;
  String? _error;

  List<Device> get devices => _devices;
  SensorReading? latestFor(String deviceId) => _latestReadings[deviceId];
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isReady => !_isLoading;

  DevicesProvider(this._deviceRepo);

  void init() {
    _deviceRepo.getDevicesStream().listen((devices) {
      _devices = devices;
      _checkReady();
    });
    refreshReadings();
  }

  void _checkReady() {
    if (_readingsLoaded) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshReadings() async {
    try {
      _latestReadings = await _deviceRepo.getLatestReadings();
      _readingsLoaded = true;
      _checkReady();
    } catch (e) {
      _error = 'Gagal memuat data: $e';
      _readingsLoaded = true;
      _checkReady();
    }
  }

  List<String> get esp32Ids {
    final ids = _devices.map((d) => d.esp32Id).toSet().toList();
    ids.sort();
    return ids;
  }

  List<Device> devicesForEsp32(String esp32Id) {
    return _devices
        .where((d) => d.esp32Id == esp32Id)
        .toList()
      ..sort((a, b) => a.sensorIndex.compareTo(b.sensorIndex));
  }

  String esp32DisplayName(String esp32Id) {
    final devices = devicesForEsp32(esp32Id);
    if (devices.isEmpty) return esp32Id;
    final location = devices.first.location;
    return '$esp32Id — $location';
  }

  int onlineCountForEsp32(String esp32Id) {
    return devicesForEsp32(esp32Id)
        .where((d) => _latestReadings[d.deviceId] != null)
        .length;
  }
}
