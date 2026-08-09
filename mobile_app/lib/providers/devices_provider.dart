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
    _deviceRepo.getDevicesStream().listen(
      (devices) {
        _devices = devices;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        // Real-time gagal (mis. tabel belum di publikasi Realtime) →
        // fallback fetch sekali agar list tetap muncul.
        _error = 'Realtime tidak tersedia, memuat data statis: $e';
        _loadInitialDevices();
      },
    );
  }

  /// Fallback: ambil daftar device sekali (tanpa realtime).
  Future<void> _loadInitialDevices() async {
    try {
      final devices = await _deviceRepo.getDevices();
      _devices = devices;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat data: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshReadings() async {
    _error = null;
    try {
      _latestReadings = await _deviceRepo.getLatestReadings();
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat data: $e';
      notifyListeners();
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

  /// Jendela waktu "online": ESP32 deep-sleep, data terbaru datang tiap
  /// readInterval (default 30 mnt) — 2x interval sebagai toleransi.
  static const Duration onlineWindow = Duration(minutes: 60);

  /// `true` jika reading ada dan masih segar (≤ 60 menit).
  bool isFresh(SensorReading? reading) {
    if (reading == null) return false;
    return DateTime.now().difference(reading.createdAt) <= onlineWindow;
  }

  /// Device dianggap online jika punya reading segar.
  bool isDeviceOnline(String deviceId) => isFresh(_latestReadings[deviceId]);

  int onlineCountForEsp32(String esp32Id) {
    return devicesForEsp32(esp32Id)
        .where((d) => isDeviceOnline(d.deviceId))
        .length;
  }
}
