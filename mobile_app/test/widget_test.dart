import 'package:flutter_test/flutter_test.dart';
import 'package:andromeda/models/device.dart';
import 'package:andromeda/models/sensor_reading.dart';
import 'package:andromeda/models/system_config.dart';
import 'package:andromeda/models/pending_command.dart';
import 'package:andromeda/models/enums.dart';
import 'package:andromeda/models/weather_location.dart';

void main() {
  group('Device', () {
    test('fromJson memetakan kolom dengan benar', () {
      final device = Device.fromJson({
        'id': 1,
        'device_id': 'petak-01',
        'esp32_id': 'esp32-01',
        'name': 'Petak 1',
        'location': 'Lahan A',
        'sensor_index': 1,
        'status': 'active',
        'created_at': '2026-08-01T08:00:00Z',
      });
      expect(device.deviceId, 'petak-01');
      expect(device.esp32Id, 'esp32-01');
      expect(device.location, 'Lahan A');
      expect(device.isActive, isTrue);
    });

    test('default status active & sensorIndex 0', () {
      final device = Device.fromJson({
        'id': 2,
        'device_id': 'petak-02',
        'name': 'Petak 2',
        'location': 'Lahan A',
      });
      expect(device.status, 'active');
      expect(device.sensorIndex, 0);
      expect(device.isActive, isTrue);
    });

    test('copyWith memperbarui nama tanpa mengubah identitas perangkat', () {
      final device = Device(
        id: 3,
        deviceId: 'petak-03',
        esp32Id: 'esp32-01',
        name: 'Petak 3',
        location: 'Lahan A',
      );

      final renamed = device.copyWith(name: 'Cabai Rawit');

      expect(renamed.name, 'Cabai Rawit');
      expect(renamed.deviceId, device.deviceId);
      expect(renamed.esp32Id, device.esp32Id);
      expect(renamed.location, device.location);
    });
  });

  group('SensorReading', () {
    test('fromJson membaca semua kolom (termasuk battery_voltage)', () {
      final reading = SensorReading.fromJson({
        'id': 10,
        'device_id': 'petak-01',
        'moisture': 1800,
        'moisture_percent': 62.5,
        'valve_status': 'ON',
        'battery_voltage': 12.4,
        'created_at': '2026-08-09T06:07:00Z',
      });
      expect(reading.moisture, 1800);
      expect(reading.moisturePercent, 62.5);
      expect(reading.isValveOpen, isTrue);
      expect(reading.batteryVoltage, 12.4);
    });

    test('fromJson toleran terhadap kolom opsional yang tidak ada', () {
      final reading = SensorReading.fromJson({
        'id': 11,
        'device_id': 'petak-01',
        'moisture': 0,
        'moisture_percent': 100,
      });
      expect(reading.valveStatus, 'OFF');
      expect(reading.isValveOpen, isFalse);
      expect(reading.batteryVoltage, isNull);
    });

    test('isDry / isWet memakai threshold dari parameter', () {
      final reading = SensorReading.fromJson({
        'id': 12,
        'device_id': 'petak-01',
        'moisture': 100,
        'moisture_percent': 25,
      });
      expect(reading.isDry(30), isTrue);
      expect(reading.isDry(20), isFalse);
      expect(reading.isWet(20), isTrue);
    });

    test('toJson hanya memuat kolom yang valid di DB', () {
      final reading = SensorReading(
        id: 13,
        deviceId: 'petak-01',
        moisture: 100,
        moisturePercent: 25.0,
      );
      final json = reading.toJson();
      expect(json.containsKey('rssi'), isFalse);
      expect(json['device_id'], 'petak-01');
      expect(json['moisture_percent'], 25.0);
    });

    test('isSensorFault true saat ADC di luar rentang valid (fix #17)', () {
      // Sensor putus / ngambang → ADC ~0 (data live petak-03..05)
      final open = SensorReading.fromJson({
        'id': 14,
        'device_id': 'petak-03',
        'moisture': 0,
        'moisture_percent': 100,
      });
      expect(open.isSensorFault, isTrue);

      // Kabel putus / pin ngambang tinggi → ADC ~4095
      final cut = SensorReading.fromJson({
        'id': 15,
        'device_id': 'petak-04',
        'moisture': 4095,
        'moisture_percent': 100,
      });
      expect(cut.isSensorFault, isTrue);

      // Rentang normal firmware (1500 basah .. 2700 kering)
      final normal = SensorReading.fromJson({
        'id': 16,
        'device_id': 'petak-01',
        'moisture': 1800,
        'moisture_percent': 75,
      });
      expect(normal.isSensorFault, isFalse);
    });
  });

  group('SystemConfig', () {
    test('default valid (auto, dry 30, wet 70)', () {
      final config = SystemConfig(id: 1, deviceId: 'petak-01');
      expect(config.isAutoMode, isTrue);
      expect(config.isValid, isTrue);
      expect(config.readIntervalMinutes, 30);
    });

    test('isValid false saat thresholdDry >= thresholdWet', () {
      final config = SystemConfig(
        id: 1,
        deviceId: 'petak-01',
        thresholdDry: 80,
        thresholdWet: 60,
      );
      expect(config.isValid, isFalse);
    });

    test('copyWith memperbarui field & updatedAt', () {
      final config = SystemConfig(id: 1, deviceId: 'petak-01');
      final updated = config.copyWith(
        thresholdDry: 20,
        thresholdWet: 60,
        valveDuration: 45,
      );
      expect(updated.thresholdDry, 20);
      expect(updated.thresholdWet, 60);
      expect(updated.valveDuration, 45);
      expect(updated.deviceId, 'petak-01');
    });
  });

  group('PendingCommand', () {
    test('fromJson + status helpers', () {
      final cmd = PendingCommand.fromJson({
        'id': 5,
        'device_id': 'petak-01',
        'command': 'VALVE_ON',
        'duration': 30,
        'status': 'pending',
        'source': 'android',
      });
      expect(cmd.isPending, isTrue);
      expect(cmd.isOpenCommand, isTrue);
      expect(cmd.isCloseCommand, isFalse);
    });

    test('status baru expired & cancelled dikenali (fix #20)', () {
      final expired = PendingCommand.fromJson({
        'id': 6,
        'device_id': 'petak-01',
        'command': 'VALVE_ON',
        'status': 'expired',
      });
      expect(expired.isExpired, isTrue);
      expect(expired.isPending, isFalse);

      final cancelled = PendingCommand.fromJson({
        'id': 7,
        'device_id': 'petak-01',
        'command': 'VALVE_OFF',
        'status': 'cancelled',
      });
      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isPending, isFalse);
    });
  });

  group('ChartRange', () {
    test('label jelas & tidak ambigu (Hari, bukan Hour)', () {
      expect(ChartRange.day1.label, 'Hari ini');
      expect(ChartRange.day7.label, '7 Hari');
      expect(ChartRange.day30.label, '30 Hari');
      expect(ChartRange.day7.days, 7);
    });
  });

  group('WeatherLocation', () {
    test('geocoding memuat kabupaten dan provinsi untuk membedakan lokasi', () {
      final location = WeatherLocation.fromGeocodingJson({
        'name': 'Banyuwangi',
        'admin2': 'Kabupaten Banyuwangi',
        'admin1': 'Jawa Timur',
        'country': 'Indonesia',
        'latitude': -8.2325,
        'longitude': 114.3576,
      });

      expect(location.name, 'Banyuwangi');
      expect(
        location.searchSubtitle,
        'Kabupaten Banyuwangi, Jawa Timur, Indonesia',
      );
      expect(location.lat, -8.2325);
      expect(location.lon, 114.3576);
    });

    test('nama tampilan menghapus bagian kosong dan duplikat', () {
      final location = WeatherLocation(
        name: 'Ponorogo',
        admin2: 'Ponorogo',
        admin1: 'Jawa Timur',
        country: 'Indonesia',
        lat: -7.87,
        lon: 111.46,
      );

      expect(location.displayName, 'Ponorogo, Jawa Timur, Indonesia');
      expect(location.searchSubtitle, 'Jawa Timur, Indonesia');
    });

    test('admin2 tetap tersimpan setelah serialisasi lokal', () {
      final original = WeatherLocation(
        name: 'Genteng',
        admin2: 'Kabupaten Banyuwangi',
        admin1: 'Jawa Timur',
        country: 'Indonesia',
        lat: -8.36,
        lon: 114.14,
      );

      final restored = WeatherLocation.fromJson(original.toJson());

      expect(restored.admin2, 'Kabupaten Banyuwangi');
      expect(restored.displayName, original.displayName);
    });
  });
}
