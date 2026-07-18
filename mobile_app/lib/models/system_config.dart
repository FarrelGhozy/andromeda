class SystemConfig {
  final int id;
  final String deviceId;
  String mode; // "auto" | "manual"
  int thresholdDry; // %
  int thresholdWet; // %
  int valveDuration; // detik
  int readInterval; // detik
  DateTime updatedAt;

  SystemConfig({
    required this.id,
    required this.deviceId,
    this.mode = 'auto',
    this.thresholdDry = 30,
    this.thresholdWet = 70,
    this.valveDuration = 30,
    this.readInterval = 1800,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get isAutoMode => mode == 'auto';
  bool get isManualMode => mode == 'manual';
  bool get isValid => thresholdDry < thresholdWet;

  int get readIntervalMinutes => readInterval ~/ 60;

  factory SystemConfig.fromJson(Map<String, dynamic> json) => SystemConfig(
        id: json['id'] ?? 0,
        deviceId: json['device_id'] ?? '',
        mode: json['mode'] ?? 'auto',
        thresholdDry: json['threshold_dry'] ?? 30,
        thresholdWet: json['threshold_wet'] ?? 70,
        valveDuration: json['valve_duration'] ?? 30,
        readInterval: json['read_interval'] ?? 1800,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'threshold_dry': thresholdDry,
        'threshold_wet': thresholdWet,
        'valve_duration': valveDuration,
        'read_interval': readInterval,
        'updated_by': 'android',
      };

  SystemConfig copyWith({
    String? mode,
    int? thresholdDry,
    int? thresholdWet,
    int? valveDuration,
    int? readInterval,
  }) =>
      SystemConfig(
        id: id,
        deviceId: deviceId,
        mode: mode ?? this.mode,
        thresholdDry: thresholdDry ?? this.thresholdDry,
        thresholdWet: thresholdWet ?? this.thresholdWet,
        valveDuration: valveDuration ?? this.valveDuration,
        readInterval: readInterval ?? this.readInterval,
        updatedAt: DateTime.now(),
      );

  @override
  String toString() =>
      'SystemConfig($deviceId: ${mode} dry=$thresholdDry wet=$thresholdWet)';
}
