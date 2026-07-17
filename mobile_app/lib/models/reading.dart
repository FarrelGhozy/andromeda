class Reading {
  final int id;
  final String deviceId;
  final int moisture;
  final double moisturePercent;
  final String valveStatus;
  final double? batteryVoltage;
  final DateTime createdAt;

  Reading({
    required this.id,
    required this.deviceId,
    required this.moisture,
    required this.moisturePercent,
    required this.valveStatus,
    this.batteryVoltage,
    required this.createdAt,
  });

  factory Reading.fromMap(Map<String, dynamic> map) {
    return Reading(
      id: map['id'] as int,
      deviceId: map['device_id'] as String,
      moisture: map['moisture'] as int,
      moisturePercent: (map['moisture_percent'] as num).toDouble(),
      valveStatus: map['valve_status'] as String? ?? 'OFF',
      batteryVoltage: map['battery_voltage'] != null
          ? (map['battery_voltage'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
