import '../../models/device.dart';
import '../../models/sensor_reading.dart';
import '../device_repository.dart';
import 'mock_database.dart';

/// [DeviceRepository] versi data contoh (mode mock).
class MockDeviceRepository implements DeviceRepository {
  final MockDatabase _db;

  MockDeviceRepository(this._db) {
    _db.startLiveSimulation();
  }

  @override
  Stream<List<Device>> getDevicesStream() async* {
    yield List.unmodifiable(_db.devices);
    yield* _db.devicesStream;
  }

  @override
  Future<List<Device>> getDevices() async =>
      List.unmodifiable(_db.devices);

  @override
  Future<void> renameDevice(String deviceId, String newName) async {
    _db.renameDevice(deviceId, newName);
  }

  @override
  Future<Device?> getDevice(String deviceId) async {
    try {
      return _db.devices.firstWhere((d) => d.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, SensorReading?>> getLatestReadings() async =>
      _db.latestAll();

  @override
  Stream<SensorReading> readingsLiveStream() => _db.liveStream;
}
