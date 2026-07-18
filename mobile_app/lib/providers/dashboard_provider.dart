import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor_reading.dart';
import '../models/system_config.dart';
import '../models/enums.dart';
import '../services/sensor_repository.dart';
import '../services/config_repository.dart';

enum DashboardState { loading, ready, error }

class DashboardProvider extends ChangeNotifier {
  final SensorRepository _sensorRepo;
  final ConfigRepository _configRepo;

  String _deviceId = '';
  DashboardState _state = DashboardState.loading;

  SensorReading? _latestReading;
  List<SensorReading> _history = [];
  SystemConfig? _config;
  String? _errorMessage;
  ChartRange _selectedChartRange = ChartRange.day1;

  StreamSubscription? _sensorSub;
  StreamSubscription? _configSub;

  // Getters
  String get deviceId => _deviceId;
  DashboardState get state => _state;
  SensorReading? get latestReading => _latestReading;
  List<SensorReading> get history => _history;
  SystemConfig? get config => _config;
  String? get errorMessage => _errorMessage;
  ChartRange get selectedChartRange => _selectedChartRange;
  int get selectedChartDays => _selectedChartRange.days;
  bool get isValveOpen => _latestReading?.isValveOpen ?? false;

  DashboardProvider(this._sensorRepo, this._configRepo);

  Future<void> loadDevice(String deviceId) async {
    _deviceId = deviceId;
    _state = DashboardState.loading;
    notifyListeners();

    // Cancel subscription lama
    _sensorSub?.cancel();
    _configSub?.cancel();

    try {
      // Subscribe realtime sensor readings
      _sensorSub = _sensorRepo
          .getLatestSensorStream(deviceId)
          .listen((reading) {
        _latestReading = reading;
        notifyListeners();
      });

      // Subscribe realtime config
      _configSub = _configRepo.getConfigStream(deviceId).listen((config) {
        _config = config;
        notifyListeners();
      });

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

  Future<void> sendValveCommand(String command,
      {int duration = 30}) async {
    try {
      await _sensorRepo.sendCommand(
        deviceId: _deviceId,
        command: command,
        duration: duration,
      );
    } catch (e) {
      _errorMessage = 'Gagal kirim perintah: $e';
      notifyListeners();
    }
  }

  Future<void> updateConfig(SystemConfig newConfig) async {
    try {
      await _configRepo.updateConfig(_deviceId, newConfig);
    } catch (e) {
      _errorMessage = 'Gagal update config: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _configSub?.cancel();
    super.dispose();
  }
}
