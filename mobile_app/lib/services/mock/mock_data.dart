import 'dart:math';
import '../../models/device.dart';
import '../../models/sensor_reading.dart';
import '../../models/system_config.dart';

/// Data contoh untuk mode mock (`APP_DATA_SOURCE=mock`).
///
/// Prinsip: data harus lolos semua aturan jujur di provider —
/// timestamp fresh (≤ onlineWindow 60 mnt), ADC dalam rentang valid
/// (100..4000, lihat `SensorReading.isSensorFault`), threshold valid.
/// Generator deterministik (seeded) supaya hasil stabil antar run & test.
class MockSeed {
  static const List<String> deviceIds = [
    'petak-01',
    'petak-02',
    'petak-03',
    'petak-04',
    'petak-05',
    'petak-06',
  ];

  static const _names = {
    'petak-01': 'Cabai Rawit',
    'petak-02': 'Tomat',
    'petak-03': 'Bawang Merah',
    'petak-04': 'Sawi',
    'petak-05': 'Kangkung',
    'petak-06': 'Terong',
  };

  static const _locations = {
    'petak-01': 'Lahan Utara',
    'petak-02': 'Lahan Utara',
    'petak-03': 'Lahan Utara',
    'petak-04': 'Lahan Selatan',
    'petak-05': 'Lahan Selatan',
    'petak-06': 'Lahan Selatan',
  };

  /// Kelembaban dasar per petak (variasi visual antar kartu).
  static const _baseMoisture = {
    'petak-01': 48.0,
    'petak-02': 62.0,
    'petak-03': 35.0,
    'petak-04': 55.0,
    'petak-05': 28.0,
    'petak-06': 70.0,
  };

  static String esp32For(String deviceId) {
    final n = int.parse(deviceId.split('-').last);
    return n <= 3 ? 'esp32-01' : 'esp32-02';
  }

  static List<Device> devices(DateTime now) {
    return deviceIds.map((id) {
      final n = int.parse(id.split('-').last);
      return Device(
        id: n,
        deviceId: id,
        esp32Id: esp32For(id),
        name: _names[id] ?? id,
        location: _locations[id] ?? '',
        sensorIndex: (n - 1) % 3,
        lastSeen: now,
      );
    }).toList();
  }

  static Map<String, SystemConfig> configs() {
    return {
      for (final id in deviceIds)
        id: SystemConfig(
          id: int.parse(id.split('-').last),
          deviceId: id,
        ),
    };
  }

  /// Riwayat per jam selama 7 hari, urutan terbaru-dulu (index 0 = latest).
  /// Pola: gelombang harian (kering siang, basah malam) + noise kecil.
  static List<SensorReading> historyFor(String deviceId, DateTime now) {
    final rand = Random(deviceId.hashCode);
    final base = _baseMoisture[deviceId] ?? 50.0;
    const totalHours = 7 * 24;
    var id = 1000 + int.parse(deviceId.split('-').last) * 10000;
    final out = <SensorReading>[];
    for (var h = 0; h < totalHours; h++) {
      final t = now.subtract(Duration(hours: h));
      // Puncak kering ~ jam 14, puncak basah ~ jam 4 pagi.
      final wave = -10 * sin(2 * pi * (t.hour - 4) / 24);
      final noise = (rand.nextDouble() - 0.5) * 6;
      final percent = (base + wave + noise).clamp(5.0, 95.0);
      out.add(SensorReading(
        id: id--,
        deviceId: deviceId,
        moisture: _rawFromPercent(percent),
        moisturePercent: double.parse(percent.toStringAsFixed(1)),
        batteryVoltage: 12.0 + rand.nextDouble() * 0.8,
        createdAt: t,
      ));
    }
    return out;
  }

  /// Balik ke raw ADC mengikuti skala firmware (1500 basah .. 2700 kering).
  static int _rawFromPercent(double percent) =>
      (2700 - percent * 12).round().clamp(100, 4000);
}
