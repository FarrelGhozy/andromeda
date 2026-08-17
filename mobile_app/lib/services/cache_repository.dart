import '../models/device.dart';
import '../models/sensor_reading.dart';
import 'local_store.dart';

/// Snapshot data terakhir yang disimpan untuk mode offline.
class CachedSnapshot {
  final List<Device> devices;
  final Map<String, SensorReading> readings;
  final DateTime savedAt;

  CachedSnapshot({
    required this.devices,
    required this.readings,
    required this.savedAt,
  });
}

/// Simpan & pulihkan snapshot data (devices + latest readings) ke SharedPreferences.
///
/// PENTING: serialisasi dilakukan MANUAL dengan menyertakan `id`, `last_seen`,
/// dan `created_at` — `toJson()` model tidak menyertakan field tersebut,
/// padahal `fromJson()` butuh untuk menghitung onlineWindow & umur data.
class CacheRepository {
  final LocalStore _store;

  CacheRepository(this._store);

  /// Simpan snapshot. GUARD: devices kosong TIDAK pernah ditulis —
  /// realtime Supabase saat offline bisa emit `[]` dan snapshot kosong
  /// akan menimpa data baik yang sudah tersimpan.
  Future<void> saveSnapshot({
    required List<Device> devices,
    required Map<String, SensorReading?> readings,
  }) async {
    if (devices.isEmpty) return;

    final deviceMaps = devices
        .map((d) => {
              ...d.toJson(),
              'id': d.id,
              'last_seen': d.lastSeen?.toIso8601String(),
              'created_at': d.createdAt.toIso8601String(),
            })
        .toList();

    final readingMaps = <String, dynamic>{};
    readings.forEach((deviceId, r) {
      if (r == null) return;
      readingMaps[deviceId] = {
        ...r.toJson(),
        'id': r.id,
        'created_at': r.createdAt.toIso8601String(),
      };
    });

    await _store.setJson(LocalStore.cacheDevicesKey, deviceMaps);
    await _store.setJson(LocalStore.cacheReadingsKey, readingMaps);
    await _store.setJson(
      LocalStore.cacheSavedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  /// Muat snapshot terakhir; `null` jika belum pernah tersimpan.
  Future<CachedSnapshot?> loadSnapshot() async {
    final devicesRaw = await _store.getJson(LocalStore.cacheDevicesKey);
    final readingsRaw = await _store.getJson(LocalStore.cacheReadingsKey);
    final savedAtRaw = await _store.getJson(LocalStore.cacheSavedAtKey);

    if (devicesRaw is! List || devicesRaw.isEmpty) return null;

    final devices = devicesRaw
        .map((m) => Device.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();

    final readings = <String, SensorReading>{};
    if (readingsRaw is Map) {
      readingsRaw.forEach((deviceId, m) {
        readings[deviceId as String] =
            SensorReading.fromJson(Map<String, dynamic>.from(m as Map));
      });
    }

    return CachedSnapshot(
      devices: devices,
      readings: readings,
      savedAt: DateTime.tryParse(savedAtRaw as String? ?? '') ?? DateTime.now(),
    );
  }
}
