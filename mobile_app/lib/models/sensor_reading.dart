class SensorReading {
  final int id;
  final String deviceId;
  final int moisture; // raw ADC 0-4095
  final double moisturePercent; // 0-100%
  final String valveStatus; // "ON" | "OFF"
  final double? batteryVoltage;
  final DateTime createdAt;

  SensorReading({
    required this.id,
    required this.deviceId,
    required this.moisture,
    required this.moisturePercent,
    this.valveStatus = 'OFF',
    this.batteryVoltage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isValveOpen => valveStatus == 'ON';

  bool isDry(int thresholdDry) => moisturePercent < thresholdDry;

  bool isWet(int thresholdWet) => moisturePercent > thresholdWet;

  factory SensorReading.fromJson(Map<String, dynamic> json) => SensorReading(
        id: json['id'] ?? 0,
        deviceId: json['device_id'] ?? '',
        moisture: json['moisture'] ?? 0,
        moisturePercent: (json['moisture_percent'] ?? 0).toDouble(),
        valveStatus: json['valve_status'] ?? 'OFF',
        batteryVoltage: (json['battery_voltage'] as num?)?.toDouble(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'moisture': moisture,
        'moisture_percent': moisturePercent,
        'valve_status': valveStatus,
        'battery_voltage': batteryVoltage,
      };

  @override
  String toString() =>
      'SensorReading($deviceId: ${moisturePercent.toStringAsFixed(1)}%)';
}
