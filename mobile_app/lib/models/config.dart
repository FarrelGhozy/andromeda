class DeviceConfig {
  final int id;
  final String deviceId;
  final String mode;
  final int thresholdDry;
  final int thresholdWet;
  final int valveDuration;
  final int readInterval;

  DeviceConfig({
    required this.id,
    required this.deviceId,
    required this.mode,
    required this.thresholdDry,
    required this.thresholdWet,
    required this.valveDuration,
    required this.readInterval,
  });

  factory DeviceConfig.fromMap(Map<String, dynamic> map) {
    return DeviceConfig(
      id: map['id'] as int,
      deviceId: map['device_id'] as String,
      mode: map['mode'] as String? ?? 'auto',
      thresholdDry: map['threshold_dry'] as int? ?? 30,
      thresholdWet: map['threshold_wet'] as int? ?? 70,
      valveDuration: map['valve_duration'] as int? ?? 30,
      readInterval: map['read_interval'] as int? ?? 1800,
    );
  }

  DeviceConfig copyWith({
    String? mode,
    int? thresholdDry,
    int? thresholdWet,
    int? valveDuration,
    int? readInterval,
  }) {
    return DeviceConfig(
      id: id,
      deviceId: deviceId,
      mode: mode ?? this.mode,
      thresholdDry: thresholdDry ?? this.thresholdDry,
      thresholdWet: thresholdWet ?? this.thresholdWet,
      valveDuration: valveDuration ?? this.valveDuration,
      readInterval: readInterval ?? this.readInterval,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      'threshold_dry': thresholdDry,
      'threshold_wet': thresholdWet,
      'valve_duration': valveDuration,
      'read_interval': readInterval,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
