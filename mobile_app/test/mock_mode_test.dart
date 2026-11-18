import 'package:andromeda/providers/devices_provider.dart';
import 'package:andromeda/services/mock/mock_config_repository.dart';
import 'package:andromeda/services/mock/mock_database.dart';
import 'package:andromeda/services/mock/mock_data.dart';
import 'package:andromeda/services/mock/mock_device_repository.dart';
import 'package:andromeda/services/mock/mock_sensor_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Delay simulasi ESP32 dipendekkan agar test cepat.
MockDatabase freshDb() => MockDatabase.seed(
      liveTickInterval: const Duration(hours: 1),
      commandExecutionDelay: const Duration(milliseconds: 10),
    );

void main() {
  group('MockSeed', () {
    test('6 petak di 2 ESP32', () {
      final devices = MockSeed.devices(DateTime.now());
      expect(devices.length, 6);
      final esp32A =
          devices.where((d) => d.esp32Id == 'esp32-01').toList();
      final esp32B =
          devices.where((d) => d.esp32Id == 'esp32-02').toList();
      expect(esp32A.length, 3);
      expect(esp32B.length, 3);
    });

    test('timestamp fresh (lolos onlineWindow)', () {
      final now = DateTime.now();
      for (final d in MockSeed.devices(now)) {
        expect(
          now.difference(d.lastSeen!).compareTo(DevicesProvider.onlineWindow),
          lessThan(0),
        );
      }
    });

    test('histori 7 hari per jam, terbaru-dulu, tanpa fault palsu', () {
      final now = DateTime.now();
      for (final id in MockSeed.deviceIds) {
        final history = MockSeed.historyFor(id, now);
        expect(history.length, 7 * 24);
        for (var i = 0; i < history.length - 1; i++) {
          expect(
            history[i].createdAt.isAfter(history[i + 1].createdAt),
            isTrue,
          );
        }
        for (final r in history) {
          expect(r.isSensorFault, isFalse,
              reason: '$id ADC ${r.moisture} di luar rentang valid');
        }
      }
    });

    test('config default valid', () {
      for (final c in MockSeed.configs().values) {
        expect(c.isValid, isTrue);
        expect(c.isAutoMode, isTrue);
      }
    });
  });

  group('MockDatabase + repositories', () {
    test('getDevices & renameDevice menyebar via stream', () async {
      final db = freshDb();
      final repo = MockDeviceRepository(db);
      expect((await repo.getDevices()).length, 6);

      final seen = <int>[];
      final sub = repo.getDevicesStream().listen((list) => seen.add(list.length));
      await repo.renameDevice('petak-01', 'Cabai Baru');
      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect((await repo.getDevice('petak-01'))!.name, 'Cabai Baru');
      expect(seen, contains(6));
      await db.dispose();
    });

    test('sendCommand: pending lalu executed + valve flip (simulasi ESP32)',
        () async {
      final db = freshDb();
      final sensor = MockSensorRepository(db);
      const id = 'petak-03';

      await sensor.sendCommand(deviceId: id, command: 'VALVE_ON');
      expect(db.latestCommands[id]!.isPending, isTrue);

      await Future.delayed(const Duration(milliseconds: 100));
      expect(db.latestCommands[id]!.isExecuted, isTrue);
      expect(db.latestFor(id)!.isValveOpen, isTrue);
      await db.dispose();
    });

    test('VALVE_OFF membalik valve yang terbuka', () async {
      final db = freshDb();
      final sensor = MockSensorRepository(db);
      // petak-02 di-seed dengan valve ON.
      expect(db.latestFor('petak-02')!.isValveOpen, isTrue);

      await sensor.sendCommand(deviceId: 'petak-02', command: 'VALVE_OFF');
      await Future.delayed(const Duration(milliseconds: 100));
      expect(db.latestCommands['petak-02']!.isExecuted, isTrue);
      expect(db.latestFor('petak-02')!.isValveOpen, isFalse);
      await db.dispose();
    });

    test('cancel membatalkan eksekusi terjadwal', () async {
      final db = freshDb();
      final sensor = MockSensorRepository(db);
      const id = 'petak-04';

      await sensor.sendCommand(deviceId: id, command: 'VALVE_ON');
      final cmdId = db.latestCommands[id]!.id;
      await sensor.updateCommandStatus(cmdId, 'cancelled');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(db.latestCommands[id]!.isCancelled, isTrue);
      expect(db.latestFor(id)!.isValveOpen, isFalse);
      await db.dispose();
    });

    test('expireStaleCommands menandai pending basi sebagai expired',
        () async {
      final db = freshDb();
      final sensor = MockSensorRepository(db);
      const id = 'petak-05';

      await sensor.sendCommand(deviceId: id, command: 'VALVE_ON');
      await sensor.expireStaleCommands(
          id, DateTime.now().add(const Duration(seconds: 1)));
      expect(db.latestCommands[id]!.isExpired, isTrue);
      await db.dispose();
    });

    test('getHistory memfilter rentang & urut menaik', () async {
      final db = freshDb();
      final sensor = MockSensorRepository(db);
      final now = DateTime.now();
      final history = await sensor.getHistory(
        deviceId: 'petak-01',
        since: now.subtract(const Duration(days: 1)),
        until: now,
      );
      expect(history, isNotEmpty);
      for (var i = 0; i < history.length - 1; i++) {
        expect(
          history[i].createdAt.isBefore(history[i + 1].createdAt) ||
              history[i].createdAt.isAtSameMomentAs(history[i + 1].createdAt),
          isTrue,
        );
      }
      await db.dispose();
    });

    test('updateConfig tersimpan & menyebar via stream', () async {
      final db = freshDb();
      final repo = MockConfigRepository(db);
      const id = 'petak-06';

      final updated = (await repo.getConfig(id))!
          .copyWith(mode: 'manual', thresholdDry: 25);
      await repo.updateConfig(id, updated);

      expect((await repo.getConfig(id))!.isManualMode, isTrue);
      expect((await repo.getConfig(id))!.thresholdDry, 25);
      final fromStream = await repo.getConfigStream(id).first;
      expect(fromStream!.thresholdDry, 25);
      await db.dispose();
    });
  });
}
