import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/sensor_reading.dart';
import '../services/device_repository.dart';
import '../services/cache_repository.dart';

class DevicesProvider extends ChangeNotifier {
  final DeviceRepository _deviceRepo;
  final CacheRepository _cacheRepo;

  List<Device> _devices = [];
  Map<String, SensorReading?> _latestReadings = {};
  bool _isLoading = true;
  bool _readingsLoaded = false;
  String? _error;
  StreamSubscription<SensorReading>? _liveSub;

  /// Waktu snapshot offline terakhir dimuat (null = data live/realtime).
  DateTime? _cachedAt;

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

  /// Kapan data tersimpan terakhir dimuat dari cache (null = data live).
  DateTime? get cachedAt => _cachedAt;

  DevicesProvider(this._deviceRepo, {required CacheRepository cacheRepo})
    : _cacheRepo = cacheRepo;

  void init() {
    _deviceRepo.getDevicesStream().listen(
      (devices) {
        _devices = devices;
        _error = null;
        _checkReady();
        // Simpan snapshot SETIAP stream devices mengirim data — di sinilah
        // daftar device lengkap pertama kali tersedia (refreshReadings di
        // init() bisa selesai lebih dulu saat _devices masih kosong, sehingga
        // guard isEmpty di CacheRepository men-skip penyimpanan).
        _cacheRepo.saveSnapshot(devices: devices, readings: _latestReadings);
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
      // Jalur fallback realtime — simpan snapshot di sini juga karena
      // stream devices bisa error (tabel belum di-publish Realtime) dan
      // listener stream tidak sempat mengeksekusi saveSnapshot.
      await _cacheRepo.saveSnapshot(
        devices: devices,
        readings: _latestReadings,
      );
    } catch (e) {
      _readingsLoaded = true;
      await _restoreFromCache();
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
      _cachedAt = null; // data live
      _checkReady();
      // Simpan snapshot untuk mode offline (skip jika devices kosong).
      await _cacheRepo.saveSnapshot(
        devices: _devices,
        readings: _latestReadings,
      );
    } catch (e) {
      _readingsLoaded = true;
      await _restoreFromCache();
      _checkReady();
    }
  }

  /// Pulihkan snapshot terakhir dari cache saat fetch gagal (offline).
  /// Tidak menimpa data live jika ada — hanya mengisi saat kosong/gagal.
  Future<void> _restoreFromCache() async {
    final snapshot = await _cacheRepo.loadSnapshot();
    if (snapshot == null) return;
    _devices = snapshot.devices;
    _latestReadings = snapshot.readings;
    _cachedAt = snapshot.savedAt;
    _error = null;
    _readingsLoaded = true;
    notifyListeners();
  }

  bool isDeviceOnline(String deviceId) {
    // last_seen di-set firmware saat bangun (satu siklus dengan reading).
    final device = _devices.where((d) => d.deviceId == deviceId).firstOrNull;
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
    final index = _devices.indexWhere((d) => d.deviceId == deviceId);
    if (index < 0) return false;
    final previous = _devices[index];

    // Perbarui layar langsung. Ini juga membuat rename tetap terasa berhasil
    // ketika Realtime sedang lambat atau tidak tersedia.
    _devices[index] = previous.copyWith(name: trimmed);
    notifyListeners();
    try {
      await _deviceRepo.renameDevice(deviceId, trimmed);
    } catch (_) {
      final currentIndex = _devices.indexWhere((d) => d.deviceId == deviceId);
      if (currentIndex >= 0) _devices[currentIndex] = previous;
      notifyListeners();
      return false;
    }

    // Cache bersifat best-effort; kegagalan cache tidak boleh membatalkan
    // rename yang sudah berhasil tersimpan di server.
    try {
      await _cacheRepo.saveSnapshot(
        devices: _devices,
        readings: _latestReadings,
      );
    } catch (_) {}
    return true;
  }

  List<String> get esp32Ids {
    final ids = _devices.map((d) => d.esp32Id).toSet().toList();
    ids.sort();
    return ids;
  }

  List<Device> devicesForEsp32(String esp32Id) {
    return _devices.where((d) => d.esp32Id == esp32Id).toList()
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
    return devicesForEsp32(
      esp32Id,
    ).where((d) => isDeviceOnline(d.deviceId)).length;
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }
}
