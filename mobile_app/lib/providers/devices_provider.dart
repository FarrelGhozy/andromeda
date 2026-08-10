import 'dart:async';
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
  StreamSubscription<SensorReading>? _liveSub;

  // Fallback "online" dari freshness reading (tanpa heartbeat):
  // ESP32 deep-sleep, data tiap readInterval (default 30 mnt) →
  // 2x interval sebagai toleransi.
  static const _onlineThresholdMinutes = 10;

  // Window "kadaluarsa" untuk last_seen heartbeat.
  // Heartbeat firmware kirim tiap 60s, jadi 3 menit cukup longgar.
  static const _heartbeatThresholdMinutes = 3;

  List<Device> get devices => _devices;
  List<Device> get allDevices => _devices;
  SensorReading? latestFor(String deviceId) => _latestReadings[deviceId];
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isReady => !_isLoading;

  DevicesProvider(this._deviceRepo);

  void init() {
    _deviceRepo.getDevicesStream().listen(
      (devices) {
        _devices = devices;
        _error = null;
        _checkReady();
      },
      onError: (Object e) {
        // Real-time gagal (mis. tabel belum dipublikasi Realtime) →
        // fallback fetch sekali agar list tetap muncul.
        _error = 'Realtime tidak tersedia, memuat data statis: $e';
        _loadInitialDevices();
      },
    );
    refreshReadings();
    _setupLiveReadings();
  }

  /// Sumber tunggal reading terbaru: update live dari realtime
  /// (INSERT/UPDATE sensor_readings) supaya list & detail selalu sinkron.
  void _setupLiveReadings() {
    _liveSub?.cancel();
    _liveSub = _deviceRepo.readingsLiveStream().listen(
      _onLiveReading,
      onError: (Object e, StackTrace st) {
        debugPrint('readings live stream error: $e');
      },
    );
  }

  void _onLiveReading(SensorReading reading) {
    final existing = _latestReadings[reading.deviceId];
    if (existing == null || !reading.createdAt.isBefore(existing.createdAt)) {
      _latestReadings[reading.deviceId] = reading;
      _readingsLoaded = true;
      _checkReady();
      notifyListeners();
    }
  }

  /// Fallback: ambil daftar device sekali (tanpa realtime).
  Future<void> _loadInitialDevices() async {
    try {
      final devices = await _deviceRepo.getDevices();
      _devices = devices;
      _checkReady();
    } catch (e) {
      _error = 'Gagal memuat data: $e';
      _readingsLoaded = true;
      _checkReady();
    }
  }

  void _checkReady() {
    if (_readingsLoaded) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshReadings() async {
    _error = null;
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

  bool isDeviceOnline(String deviceId) {
    // 1. Prioritas: heartbeat last_seen dari perangkat (akurat).
    final device =
        _devices.where((d) => d.deviceId == deviceId).firstOrNull;
    final lastSeen = device?.lastSeen;
    if (lastSeen != null) {
      return DateTime.now().difference(lastSeen).inMinutes <
          _heartbeatThresholdMinutes;
    }
    // 2. Fallback: kalau belum ada heartbeat, tebak dari data terakhir.
    final reading = _latestReadings[deviceId];
    if (reading == null) return false;
    return DateTime.now().difference(reading.createdAt).inMinutes <
        _onlineThresholdMinutes;
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

  /// Jendela "data segar" untuk GAUGE (bukan online count):
  /// reading dianggap masih layak tampil ≤ 2x readInterval.
  static const Duration onlineWindow = Duration(minutes: 60);

  /// `true` jika reading ada dan masih segar (≤ 60 menit).
  bool isFresh(SensorReading? reading) {
    if (reading == null) return false;
    return DateTime.now().difference(reading.createdAt) <= onlineWindow;
  }

  int onlineCountForEsp32(String esp32Id) {
    return devicesForEsp32(esp32Id)
        .where((d) => isDeviceOnline(d.deviceId))
        .length;
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }
}
