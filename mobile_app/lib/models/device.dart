class Device {
  final int id;
  final String deviceId;
  final String name;
  final String? location;
  final String status;

  Device({
    required this.id,
    required this.deviceId,
    required this.name,
    this.location,
    required this.status,
  });

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as int,
      deviceId: map['device_id'] as String,
      name: map['name'] as String,
      location: map['location'] as String?,
      status: map['status'] as String? ?? 'active',
    );
  }
}
