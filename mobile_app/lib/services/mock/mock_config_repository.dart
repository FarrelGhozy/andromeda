import '../../models/system_config.dart';
import '../config_repository.dart';
import 'mock_database.dart';

/// [ConfigRepository] versi data contoh (mode mock).
class MockConfigRepository implements ConfigRepository {
  final MockDatabase _db;

  MockConfigRepository(this._db);

  @override
  Stream<SystemConfig?> getConfigStream(String deviceId) async* {
    yield _db.configs[deviceId];
    await for (final entry in _db.configStream) {
      if (entry.key == deviceId) yield entry.value;
    }
  }

  @override
  Future<SystemConfig?> getConfig(String deviceId) async =>
      _db.configs[deviceId];

  @override
  Future<void> updateConfig(String deviceId, SystemConfig config) async {
    _db.updateConfig(deviceId, config);
  }
}
