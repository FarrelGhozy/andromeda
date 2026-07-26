class Device {
  final int id;
  final String deviceId;
  final String esp32Id;
  final String name;
  final String location;
  final int sensorIndex;
  final String status;
  final DateTime createdAt;

  Device({
    required this.id,
    required this.deviceId,
    this.esp32Id = '',
    required this.name,
    required this.location,
    this.sensorIndex = 0,
    this.status = 'active',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isActive => status == 'active';

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] ?? 0,
        deviceId: json['device_id'] ?? '',
        esp32Id: json['esp32_id'] ?? '',
        name: json['name'] ?? '',
        location: json['location'] ?? '',
        sensorIndex: json['sensor_index'] ?? 0,
        status: json['status'] ?? 'active',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'esp32_id': esp32Id,
        'name': name,
        'location': location,
        'sensor_index': sensorIndex,
        'status': status,
      };

  @override
  String toString() => 'Device($deviceId: $name)';
}
