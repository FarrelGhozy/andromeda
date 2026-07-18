class Device {
  final int id;
  final String deviceId; // "petak-01"
  final String name; // "Petak 1 — Padi"
  final String location; // "Lahan A"
  final String status; // "active" | "inactive"
  final DateTime createdAt;

  Device({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.location,
    this.status = 'active',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isActive => status == 'active';

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] ?? 0,
        deviceId: json['device_id'] ?? '',
        name: json['name'] ?? '',
        location: json['location'] ?? '',
        status: json['status'] ?? 'active',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'name': name,
        'location': location,
        'status': status,
      };

  @override
  String toString() => 'Device($deviceId: $name)';
}
