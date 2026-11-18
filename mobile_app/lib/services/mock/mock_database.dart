import 'dart:async';
import 'dart:math';
import '../../models/device.dart';
import '../../models/pending_command.dart';
import '../../models/sensor_reading.dart';
import '../../models/system_config.dart';
import 'mock_data.dart';

/// Penyimpanan in-memory bersama untuk semua repository mock.
///
/// Satu instance dipakai bareng oleh MockDeviceRepository,
/// MockSensorRepository, dan MockConfigRepository — persis seperti
/// satu database Supabase yang diakses tiga repository Supabase.
///
/// Selain menyimpan state, class ini juga mensimulasikan perilaku
/// perangkat & server:
/// - Tick live tiap [liveTickInterval]: kelembaban bergeser sedikit,
///   reading baru di-emit (pengganti Realtime Supabase).
/// - Eksekusi perintah ala ESP32: command `pending` → `executed`
///   setelah [commandExecutionDelay], valve ikut flip.
class MockDatabase {
  final Duration liveTickInterval;
  final Duration commandExecutionDelay;

  List<Device> devices;
  final Map<String, List<SensorReading>> history;
  final Map<String, SystemConfig> configs;
  final Map<String, PendingCommand?> latestCommands;

  int _nextReadingId = 900000;
  int _nextCommandId = 9000;
  final _rand = Random(42);

  final _devicesController = StreamController<List<Device>>.broadcast();
  final _liveController = StreamController<SensorReading>.broadcast();
  final _configController =
      StreamController<MapEntry<String, SystemConfig>>.broadcast();
  final _commandController =
      StreamController<MapEntry<String, PendingCommand>>.broadcast();

  Timer? _tick;

  MockDatabase._({
    required this.devices,
    required this.history,
    required this.configs,
    required this.latestCommands,
    required this.liveTickInterval,
    required this.commandExecutionDelay,
  });

  factory MockDatabase.seed({
    Duration liveTickInterval = const Duration(seconds: 5),
    Duration commandExecutionDelay = const Duration(seconds: 2),
  }) {
    final now = DateTime.now();
    final history = <String, List<SensorReading>>{};
    for (final id in MockSeed.deviceIds) {
      history[id] = MockSeed.historyFor(id, now);
    }
    // Satu petak divisualkan TERBUKA supaya status ON terlihat di mock.
    final open = history['petak-02']!.first;
    history['petak-02']![0] = SensorReading(
      id: open.id,
      deviceId: open.deviceId,
      moisture: open.moisture,
      moisturePercent: open.moisturePercent,
      valveStatus: 'ON',
      batteryVoltage: open.batteryVoltage,
      createdAt: now,
    );
    return MockDatabase._(
      devices: MockSeed.devices(now),
      history: history,
      configs: MockSeed.configs(),
      latestCommands: {for (final id in MockSeed.deviceIds) id: null},
      liveTickInterval: liveTickInterval,
      commandExecutionDelay: commandExecutionDelay,
    );
  }

  Stream<List<Device>> get devicesStream => _devicesController.stream;
  Stream<SensorReading> get liveStream => _liveController.stream;
  Stream<MapEntry<String, SystemConfig>> get configStream =>
      _configController.stream;
  Stream<MapEntry<String, PendingCommand>> get commandStream =>
      _commandController.stream;

  SensorReading? latestFor(String deviceId) {
    final list = history[deviceId];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  Map<String, SensorReading?> latestAll() => {
        for (final id in MockSeed.deviceIds) id: latestFor(id),
      };

  /// Jalankan simulasi live. Dipanggil sekali dari factory repository.
  void startLiveSimulation() {
    _tick ??= Timer.periodic(liveTickInterval, (_) => _liveTick());
  }

  void _liveTick() {
    if (_devicesController.isClosed) return;
    final now = DateTime.now();
    for (final id in MockSeed.deviceIds) {
      final prev = latestFor(id);
      if (prev == null) continue;
      final drift = (_rand.nextDouble() - 0.5) * 3;
      final percent =
          (prev.moisturePercent + drift).clamp(5.0, 95.0);
      final reading = SensorReading(
        id: ++_nextReadingId,
        deviceId: id,
        moisture: (2700 - percent * 12).round().clamp(100, 4000),
        moisturePercent: double.parse(percent.toStringAsFixed(1)),
        valveStatus: prev.valveStatus,
        batteryVoltage: prev.batteryVoltage,
        createdAt: now,
      );
      history[id]!.insert(0, reading);
      if (history[id]!.length > 600) {
        history[id]!.removeRange(600, history[id]!.length);
      }
      _liveController.add(reading);
    }
    // lastSeen segar terus supaya perangkat terbaca online.
    devices = [
      for (final d in devices) d.copyWith(lastSeen: now),
    ];
    _devicesController.add(List.unmodifiable(devices));
  }

  void renameDevice(String deviceId, String newName) {
    devices = [
      for (final d in devices)
        if (d.deviceId == deviceId) d.copyWith(name: newName) else d,
    ];
    _devicesController.add(List.unmodifiable(devices));
  }

  void updateConfig(String deviceId, SystemConfig config) {
    configs[deviceId] = config;
    _configController.add(MapEntry(deviceId, config));
  }

  /// Kirim perintah ala aplikasi. Simulasi ESP32: tetap `pending` dulu,
  /// lalu dieksekusi setelah [commandExecutionDelay].
  PendingCommand sendCommand({
    required String deviceId,
    required String command,
    required int duration,
    required String source,
  }) {
    final cmd = PendingCommand(
      id: ++_nextCommandId,
      deviceId: deviceId,
      command: command,
      duration: duration,
      source: source,
      createdAt: DateTime.now(),
    );
    latestCommands[deviceId] = cmd;
    _commandController.add(MapEntry(deviceId, cmd));

    Timer(commandExecutionDelay, () {
      if (_commandController.isClosed) return;
      final current = latestCommands[deviceId];
      // Hanya eksekusi kalau command ini masih pending (belum di-cancel).
      if (current == null || current.id != cmd.id || !current.isPending) {
        return;
      }
      final executed = PendingCommand(
        id: cmd.id,
        deviceId: cmd.deviceId,
        command: cmd.command,
        duration: cmd.duration,
        status: 'executed',
        source: cmd.source,
        createdAt: cmd.createdAt,
        executedAt: DateTime.now(),
      );
      latestCommands[deviceId] = executed;
      _commandController.add(MapEntry(deviceId, executed));

      final prev = latestFor(deviceId);
      if (prev != null) {
        final flipped = SensorReading(
          id: ++_nextReadingId,
          deviceId: deviceId,
          moisture: prev.moisture,
          moisturePercent: prev.moisturePercent,
          valveStatus: cmd.isOpenCommand ? 'ON' : 'OFF',
          batteryVoltage: prev.batteryVoltage,
          createdAt: DateTime.now(),
        );
        history[deviceId]!.insert(0, flipped);
        _liveController.add(flipped);
      }
    });
    return cmd;
  }

  /// Ubah status command (cancelled dari app).
  bool updateCommandStatus(int commandId, String status) {
    for (final entry in latestCommands.entries) {
      final cmd = entry.value;
      if (cmd != null && cmd.id == commandId) {
        final updated = PendingCommand(
          id: cmd.id,
          deviceId: cmd.deviceId,
          command: cmd.command,
          duration: cmd.duration,
          status: status,
          source: cmd.source,
          createdAt: cmd.createdAt,
          executedAt: cmd.executedAt,
        );
        latestCommands[entry.key] = updated;
        _commandController.add(MapEntry(entry.key, updated));
        return true;
      }
    }
    return false;
  }

  /// Tandai command pending yang basi sebagai expired.
  void expireStaleCommands(String deviceId, DateTime olderThan) {
    final cmd = latestCommands[deviceId];
    if (cmd != null &&
        cmd.isPending &&
        cmd.createdAt.isBefore(olderThan)) {
      updateCommandStatus(cmd.id, 'expired');
    }
  }

  Future<void> dispose() async {
    _tick?.cancel();
    await _devicesController.close();
    await _liveController.close();
    await _configController.close();
    await _commandController.close();
  }
}
