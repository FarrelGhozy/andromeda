import 'package:flutter/material.dart';
import '../config/theme_config.dart';
import '../models/device.dart';
import '../models/sensor_reading.dart';
import 'moisture_gauge.dart';
import 'status_badge.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final SensorReading? reading;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    this.reading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final moisture = reading?.moisturePercent ?? 0;
    final isOnline = reading != null;
    final isValveOn = reading?.isValveOpen ?? false;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Gauge kecil di kiri
              SizedBox(
                width: 72,
                height: 72,
                child: MoistureGauge(
                  percent: moisture,
                  size: 72,
                  showLabel: false,
                ),
              ),
              const SizedBox(width: 16),

              // Info tengah
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama petak
                    Row(
                      children: [
                        Icon(
                          Icons.eco,
                          size: 18,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            device.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Lokasi dan kelembaban
                    Text(
                      '${device.location} • $moisture%',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Baris status
                    Row(
                      children: [
                        // Online/Offline badge
                        _miniBadge(
                          isOnline ? 'Online' : 'Offline',
                          isOnline ? AppColors.success : AppColors.offline,
                        ),
                        const SizedBox(width: 8),
                        // Valve status
                        StatusBadge(
                          text: isValveOn ? 'Valve ON' : 'Valve OFF',
                          color: isValveOn ? AppColors.danger : AppColors.success,
                          fontSize: 11,
                        ),
                        if (reading?.createdAt != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.access_time,
                              size: 12, color: Colors.grey[400]),
                          const SizedBox(width: 2),
                          Text(
                            _formatTimeAgo(reading!.createdAt),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}j';
    return '${diff.inDays}h';
  }
}
