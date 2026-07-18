import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/sensor_reading.dart';
import '../services/device_repository.dart';

class DevicesProvider extends ChangeNotifier {
  final DeviceRepository _deviceRepo;

  List<Device> _devices = [];
  Map<String, SensorReading?> _latestReadings = {};
  bool _isLoading = true;
  String? _error;

  List<Device> get devices => _devices;
  SensorReading? latestFor(String deviceId) => _latestReadings[deviceId];
  bool get isLoading => _isLoading;
  String? get error => _error;

  DevicesProvider(this._deviceRepo);

  void init() {
    _deviceRepo.getDevicesStream().listen((devices) {
      _devices = devices;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> refreshReadings() async {
    try {
      _latestReadings = await _deviceRepo.getLatestReadings();
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat data: $e';
      notifyListeners();
    }
  }
}
