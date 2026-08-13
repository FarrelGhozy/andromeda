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

  // =====================================================================
  // SATU SUMBER KEBENARAN umur data (fix #29).
  // ESP32 deep-sleep: bangun tiap read_interval (default 30 mnt), kirim
  // reading + last_seen, lalu tidur. Jadi device TIDAK mengirim heartbeat
  // terus-menerus; "online" berarti "sehat & masih dalam siklus berjalan".
  // onlineWindow = 2× read_interval default (30 mnt) sebagai toleransi.
  // Seluruh tampilan (badge list, gauge, status valve) memakai window ini
  // supaya tidak ada kontradiksi Offline vs data "segar".
  static const Duration onlineWindow = Duration(minutes: 60);
  // =====================================================================

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
    // last_seen di-set firmware saat bangun (satu siklus dengan reading).
    final device =
        _devices.where((d) => d.deviceId == deviceId).firstOrNull;
    final lastSeen = device?.lastSeen;
    if (lastSeen != null &&
        DateTime.now().difference(lastSeen) <= onlineWindow) {
      return true;
    }
    // Fallback: tebak dari data terakhir yang masih segar.
    final reading = _latestReadings[deviceId];
    if (reading == null) return false;
    return DateTime.now().difference(reading.createdAt) <= onlineWindow;
  }

  /// Nama tampilan petak: nama custom jika ada, fallback ke 'PETAK 01'.
  String displayNameFor(String deviceId) {
    final device = _devices.where((d) => d.deviceId == deviceId).firstOrNull;
    final name = device?.name.trim() ?? '';
    if (name.isNotEmpty) return name;
    return deviceId.toUpperCase().replaceAll('-', ' ');
  }

  /// Ganti nama petak dari aplikasi. Return `true` jika tersimpan.
  /// Tidak menyentuh `_error` (dipakai home_screen untuk ErrorBanner).
  Future<bool> renameDevice(String deviceId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed.length > 40) return false;
    try {
      await _deviceRepo.renameDevice(deviceId, trimmed);
      return true;
    } catch (_) {
      return false;
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

  /// `true` jika reading ada dan masih segar (≤ onlineWindow).
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
