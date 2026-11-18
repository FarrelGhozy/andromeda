import '../../models/pending_command.dart';
import '../../models/sensor_reading.dart';
import '../sensor_repository.dart';
import 'mock_database.dart';

/// [SensorRepository] versi data contoh (mode mock).
class MockSensorRepository implements SensorRepository {
  final MockDatabase _db;

  MockSensorRepository(this._db);

  @override
  Future<SensorReading?> getLatestReading(String deviceId) async =>
      _db.latestFor(deviceId);

  @override
  Stream<SensorReading?> getLatestSensorStream(String deviceId) =>
      Stream.value(_db.latestFor(deviceId));

  @override
  Stream<List<SensorReading>> getSensorHistoryStream(String deviceId,
          {int limit = 100}) =>
      Stream.value(_db.history[deviceId]?.take(limit).toList() ?? []);

  @override
  Future<List<SensorReading>> getHistory({
    required String deviceId,
    required DateTime since,
    required DateTime until,
  }) async {
    final list = _db.history[deviceId] ?? [];
    // Urutan menaik mengikuti `.order('created_at')` versi Supabase.
    return list
        .where((r) =>
            !r.createdAt.isBefore(since) && !r.createdAt.isAfter(until))
        .toList()
        .reversed
        .toList();
  }

  @override
  Future<void> sendCommand({
    required String deviceId,
    required String command,
    int duration = 30,
    String source = 'android',
  }) async {
    _db.sendCommand(
      deviceId: deviceId,
      command: command,
      duration: duration,
      source: source,
    );
  }

  @override
  Stream<PendingCommand?> getLatestCommandStream(String deviceId) async* {
    yield _db.latestCommands[deviceId];
    await for (final entry in _db.commandStream) {
      if (entry.key == deviceId) yield entry.value;
    }
  }

  @override
  Future<void> updateCommandStatus(int commandId, String status) async {
    _db.updateCommandStatus(commandId, status);
  }

  @override
  Future<void> expireStaleCommands(
      String deviceId, DateTime olderThan) async {
    _db.expireStaleCommands(deviceId, olderThan);
  }
}
