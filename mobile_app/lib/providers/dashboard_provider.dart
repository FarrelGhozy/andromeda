import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor_reading.dart';
import '../models/system_config.dart';
import '../models/pending_command.dart';
import '../models/enums.dart';
import '../services/sensor_repository.dart';
import '../services/config_repository.dart';
import 'devices_provider.dart';

enum DashboardState { loading, ready, error }

/// Status valve yang JUJUR berdasarkan umur data (fix #16):
/// data basi/tidak ada ≠ "tertutup" — itu "tidak diketahui".
enum ValveDisplayStatus { open, closed, unknown }

/// State machine perintah valve (fix #18):
/// idle → sending → pending → executed | expired | cancelled
enum CommandState { idle, sending, pending, executed, expired, cancelled }

class DashboardProvider extends ChangeNotifier {
  final SensorRepository _sensorRepo;
  final ConfigRepository _configRepo;

  /// Sumber tunggal reading terbaru (sync dengan list petak).
  final DevicesProvider _devicesProvider;

  String _deviceId = '';
  DashboardState _state = DashboardState.loading;

  SensorReading? _latestReading;
  List<SensorReading> _history = [];
  SystemConfig? _config;
  String? _errorMessage;
  ChartRange _selectedChartRange = ChartRange.day1;

  StreamSubscription? _configSub;
  StreamSubscription? _commandSub;
  VoidCallback? _devicesListener;

  bool _sendingCommand = false;

  // --- State machine command (fix #18/#19/#20) ---
  PendingCommand? _latestCommand;
  Timer? _expiryTimer; // command pending > 2×read_interval → expired
  Timer? _autoOffTimer; // fallback VALVE_OFF bila ESP32 tak eksekusi
  Timer? _countdownTimer; // ticker UI countdown auto-OFF
  Duration _autoOffRemaining = Duration.zero;

  // Getters
  String get deviceId => _deviceId;
  bool get sendingCommand => _sendingCommand;
  DashboardState get state => _state;
  SensorReading? get latestReading => _latestReading;
  List<SensorReading> get history => _history;
  SystemConfig? get config => _config;
  String? get errorMessage => _errorMessage;
  ChartRange get selectedChartRange => _selectedChartRange;
  int get selectedChartDays => _selectedChartRange.days;
  /// Valve dianggap terbuka hanya jika reading SEGAR mengatakannya.
  bool get isValveOpen => _latestReading?.isValveOpen ?? false;

  PendingCommand? get latestCommand => _latestCommand;
  Duration get autoOffRemaining => _autoOffRemaining;

  /// Status valve dengan kesadaran umur data (fix #16/#29):
  /// - device online (satu sumber kebenaran: DevicesProvider.onlineWindow)
  ///   → open/closed sesuai `valve_status`
  /// - device offline / data basi / tidak ada → `unknown` (bukan TERTUTUP!)
  ValveDisplayStatus get valveDisplayStatus {
    final r = _latestReading;
    if (r == null) return ValveDisplayStatus.unknown;
    if (!_devicesProvider.isDeviceOnline(_deviceId)) {
      return ValveDisplayStatus.unknown;
    }
    final fresh = DateTime.now().difference(r.createdAt) <=
        DevicesProvider.onlineWindow;
    if (!fresh) return ValveDisplayStatus.unknown;
    return r.isValveOpen ? ValveDisplayStatus.open : ValveDisplayStatus.closed;
  }

  /// `true` jika reading saat ini masih segar & perangkat online
  /// (satu sumber kebenaran sama dengan badge Online di list petak).
  bool get isFresh {
    final r = _latestReading;
    if (r == null) return false;
    return _devicesProvider.isDeviceOnline(_deviceId) &&
        DateTime.now().difference(r.createdAt) <=
            DevicesProvider.onlineWindow;
  }

  /// Status perintah valve terbaru (fix #18).
  CommandState get commandState {
    if (_sendingCommand) return CommandState.sending;
    final c = _latestCommand;
    if (c == null) return CommandState.idle;
    return switch (c.status) {
      'pending' => CommandState.pending,
      'executed' => CommandState.executed,
      'cancelled' => CommandState.cancelled,
      'expired' => CommandState.expired,
      _ => CommandState.idle,
    };
  }

  DashboardProvider(this._sensorRepo, this._configRepo, this._devicesProvider);

  Future<void> loadDevice(String deviceId) async {
    _deviceId = deviceId;
    _state = DashboardState.loading;
    notifyListeners();

    // Cancel subscription lama
    if (_devicesListener != null) {
      _devicesProvider.removeListener(_devicesListener!);
      _devicesListener = null;
    }
    _configSub?.cancel();
    _commandSub?.cancel();
    _expiryTimer?.cancel();
    _autoOffTimer?.cancel();
    _countdownTimer?.cancel();

    try {
      // SUMBER TUNGGAL: baca nilai terbaru dari DevicesProvider (sama
      // dengan yang tampil di list petak) → dijamin selalu sinkron.
      _latestReading = _devicesProvider.latestFor(deviceId);
      // Fallback: jika map kosong (realtime belum dapat), fetch sekali.
      _latestReading ??= await _sensorRepo.getLatestReading(deviceId);

      _devicesListener = () {
        _latestReading = _devicesProvider.latestFor(_deviceId);
        notifyListeners();
      };
      _devicesProvider.addListener(_devicesListener!);
      notifyListeners();

      // Subscribe realtime config
      _configSub = _configRepo.getConfigStream(deviceId).listen((config) {
        _config = config;
        notifyListeners();
      }, onError: (Object e, StackTrace st) {
        debugPrint('config stream error: $e');
      });
      // Fallback config sekali jika stream gagal/diam.
      _config ??= await _configRepo.getConfig(deviceId);

      // Subscribe realtime command terbaru (fix #18)
      _commandSub =
          _sensorRepo.getLatestCommandStream(deviceId).listen((command) {
        _latestCommand = command;
        if (command != null && command.isExecuted) {
          // ESP32 sudah eksekusi → firmware auto-close menangani sisanya;
          // batal timer fallback.
          _autoOffTimer?.cancel();
          _countdownTimer?.cancel();
          _autoOffRemaining = Duration.zero;
        }
        notifyListeners();
      }, onError: (Object e, StackTrace st) {
        debugPrint('command stream error: $e');
      });

      // Expiry command pending yang basi (> 2×read_interval) (fix #20)
      final interval = _config?.readIntervalMinutes ?? 30;
      await _sensorRepo.expireStaleCommands(
        deviceId,
        DateTime.now().subtract(Duration(minutes: 2 * interval)),
      );

      // Load history
      await _loadHistory();

      _state = DashboardState.ready;
    } catch (e) {
      _state = DashboardState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final since = DateTime.now()
        .subtract(Duration(days: _selectedChartRange.days));
    _history = await _sensorRepo.getHistory(
      deviceId: _deviceId,
      since: since,
      until: DateTime.now(),
    );
  }

  Future<void> setChartRange(ChartRange range) async {
    _selectedChartRange = range;
    await _loadHistory();
    notifyListeners();
  }

  /// Kirim perintah valve. Return `true` jika berhasil terkirim.
  Future<bool> sendValveCommand(String command,
      {int duration = 30}) async {
    if (_sendingCommand) return false;
    _sendingCommand = true;
    notifyListeners();
    try {
      await _sensorRepo.sendCommand(
        deviceId: _deviceId,
        command: command,
        duration: duration,
      );
      _errorMessage = null;

      if (command == 'VALVE_ON') {
        // Fix #19: jadwalkan auto-OFF fallback — bila ESP32 tidak
        // mengeksekusi VALVE_ON dalam `duration`, app memaksa TUTUP
        // agar valve tidak terbuka tanpa batas.
        _armAutoOff(duration);
      }
      // Fix #20: command pending yang tak dieksekusi dalam
      // 2×read_interval → ditandai expired (lihat juga expiry saat load).
      _armExpiry();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal kirim perintah: $e';
      return false;
    } finally {
      _sendingCommand = false;
      notifyListeners();
    }
  }

  /// Fix #19: fallback keamanan — VALVE_OFF otomatis dengan countdown UI.
  void _armAutoOff(int durationSeconds) {
    _autoOffTimer?.cancel();
    _countdownTimer?.cancel();
    _autoOffRemaining = Duration(seconds: durationSeconds);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_autoOffRemaining > Duration.zero) {
        _autoOffRemaining -= const Duration(seconds: 1);
        notifyListeners();
      } else {
        _countdownTimer?.cancel();
      }
    });

    _autoOffTimer = Timer(Duration(seconds: durationSeconds), () async {
      // Bila VALVE_ON masih pending (belum dieksekusi ESP32) → paksa
      // kirim VALVE_OFF (source android_auto) sebagai pengaman.
      final c = _latestCommand;
      if (c != null && c.isOpenCommand && c.isPending) {
        try {
          await _sensorRepo.sendCommand(
            deviceId: _deviceId,
            command: 'VALVE_OFF',
            duration: 5,
            source: 'android_auto',
          );
        } catch (_) {
          // gagal kirim fallback — valve sudah terbuka sejak command
          // pending dikirim; user tetap bisa TUTUP manual.
        }
      }
      _autoOffRemaining = Duration.zero;
      notifyListeners();
    });
  }

  /// Fix #20: command pending yang tak dieksekusi dalam 2×read_interval
  /// ditandai expired supaya tidak "menyalakan" valve di kemudian hari.
  void _armExpiry() {
    _expiryTimer?.cancel();
    final interval = _config?.readIntervalMinutes ?? 30;
    _expiryTimer = Timer(Duration(minutes: 2 * interval), () async {
      final c = _latestCommand;
      if (c != null && c.isPending) {
        try {
          await _sensorRepo.updateCommandStatus(c.id, 'expired');
        } catch (_) {}
      }
    });
  }

  /// Fix #20: batalkan command yang masih pending.
  Future<bool> cancelPendingCommand() async {
    final c = _latestCommand;
    if (c == null || !c.isPending) return false;
    try {
      await _sensorRepo.updateCommandStatus(c.id, 'cancelled');
      _autoOffTimer?.cancel();
      _countdownTimer?.cancel();
      _autoOffRemaining = Duration.zero;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal membatalkan perintah: $e';
      return false;
    }
  }

  /// Update config. Mengembalikan `true` jika tersimpan di server.
  Future<bool> updateConfig(SystemConfig newConfig) async {
    try {
      await _configRepo.updateConfig(_deviceId, newConfig);
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Gagal update config: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    if (_devicesListener != null) {
      _devicesProvider.removeListener(_devicesListener!);
      _devicesListener = null;
    }
    _configSub?.cancel();
    _commandSub?.cancel();
    _expiryTimer?.cancel();
    _autoOffTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
