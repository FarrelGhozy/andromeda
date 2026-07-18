enum ValveStatus { on, off, unknown }

enum DeviceMode { auto, manual }

enum ConnectionStatus { connected, disconnected, error }

enum ChartRange { day1, day7, day30 }

extension ValveStatusExtension on ValveStatus {
  String get label {
    switch (this) {
      case ValveStatus.on:
        return 'ON';
      case ValveStatus.off:
        return 'OFF';
      case ValveStatus.unknown:
        return '—';
    }
  }

  bool get isOpen => this == ValveStatus.on;
}

extension DeviceModeExtension on DeviceMode {
  String get label {
    switch (this) {
      case DeviceMode.auto:
        return 'Otomatis';
      case DeviceMode.manual:
        return 'Manual';
    }
  }
}

extension ChartRangeExtension on ChartRange {
  String get label {
    switch (this) {
      case ChartRange.day1:
        return '1H';
      case ChartRange.day7:
        return '7H';
      case ChartRange.day30:
        return '30H';
    }
  }

  int get days {
    switch (this) {
      case ChartRange.day1:
        return 1;
      case ChartRange.day7:
        return 7;
      case ChartRange.day30:
        return 30;
    }
  }
}
