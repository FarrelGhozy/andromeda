import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/reading.dart';
import '../models/config.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final Reading? reading;
  final DeviceConfig? config;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    this.reading,
    this.config,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final moisture = reading?.moisturePercent ?? 0;
    final isValveOn = reading?.valveStatus == 'ON';
    final isAuto = config?.mode == 'auto';

    Color moistureColor;
    if (moisture < (config?.thresholdDry ?? 30)) {
      moistureColor = Colors.red;
    } else if (moisture > (config?.thresholdWet ?? 70)) {
      moistureColor = Colors.blue;
    } else {
      moistureColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: moistureColor,
          child: Text(
            '${moisture.toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.location ?? 'Lokasi belum diatur'),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    isValveOn ? 'VALVE ON' : 'VALVE OFF',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: isValveOn ? Colors.green.shade100 : Colors.grey.shade200,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    isAuto ? 'AUTO' : 'MANUAL',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: isAuto ? Colors.blue.shade100 : Colors.orange.shade100,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
