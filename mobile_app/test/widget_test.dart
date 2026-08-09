import 'package:flutter_test/flutter_test.dart';
import 'package:andromeda/models/device.dart';
import 'package:andromeda/models/sensor_reading.dart';
import 'package:andromeda/models/system_config.dart';
import 'package:andromeda/models/pending_command.dart';
import 'package:andromeda/models/enums.dart';

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
  });

  group('ChartRange', () {
    test('label jelas & tidak ambigu (Hari, bukan Hour)', () {
      expect(ChartRange.day1.label, 'Hari ini');
      expect(ChartRange.day7.label, '7 Hari');
      expect(ChartRange.day30.label, '30 Hari');
      expect(ChartRange.day7.days, 7);
    });
  });
}
