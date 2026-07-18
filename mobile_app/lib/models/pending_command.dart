class PendingCommand {
  final int id;
  final String deviceId;
  final String command; // "VALVE_ON" | "VALVE_OFF"
  final int duration; // detik
  final String status; // "pending" | "executed" | "cancelled"
  final String source; // "android" | "system"
  final DateTime createdAt;
  final DateTime? executedAt;

  PendingCommand({
    required this.id,
    required this.deviceId,
    required this.command,
    this.duration = 30,
    this.status = 'pending',
    this.source = 'android',
    DateTime? createdAt,
    this.executedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPending => status == 'pending';
  bool get isExecuted => status == 'executed';
  bool get isOpenCommand => command == 'VALVE_ON';
  bool get isCloseCommand => command == 'VALVE_OFF';

  factory PendingCommand.fromJson(Map<String, dynamic> json) => PendingCommand(
        id: json['id'] ?? 0,
        deviceId: json['device_id'] ?? '',
        command: json['command'] ?? '',
        duration: json['duration'] ?? 30,
        status: json['status'] ?? 'pending',
        source: json['source'] ?? 'android',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        executedAt: json['executed_at'] != null
            ? DateTime.parse(json['executed_at'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'command': command,
        'duration': duration,
        'status': 'pending',
        'source': source,
      };
}
