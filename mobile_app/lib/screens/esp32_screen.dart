import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/devices_provider.dart';
import '../widgets/moisture_gauge.dart';
import '../widgets/status_badge.dart';
import '../routes.dart';

class Esp32Screen extends StatelessWidget {
  final String esp32Id;
  const Esp32Screen({super.key, required this.esp32Id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(esp32Id),
      ),
      body: Consumer<DevicesProvider>(
        builder: (context, provider, _) {
          final devices = provider.devicesForEsp32(esp32Id);
          if (devices.isEmpty) {
            return const Center(child: Text('Tidak ada petak'));
          }

          return RefreshIndicator(
            onRefresh: provider.refreshReadings,
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final reading = provider.latestFor(device.deviceId);
                return _PetakCard(
                  device: device,
                  reading: reading,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.dashboard,
                    arguments: device.deviceId,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PetakCard extends StatelessWidget {
  final dynamic device;
  final dynamic reading;
  final VoidCallback onTap;

  const _PetakCard({
    required this.device,
    required this.reading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final moisture = reading?.moisturePercent ?? 0.0;
    final isOnline = reading != null;
    final isValveOn = reading?.isValveOpen ?? false;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MoistureGauge(percent: moisture, size: 100),
              const SizedBox(height: 8),
              Text(
                device.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _miniBadge(
                    isOnline ? 'Online' : 'Offline',
                    isOnline ? AppColors.success : AppColors.offline,
                  ),
                  const SizedBox(width: 4),
                  StatusBadge(
                    text: isValveOn ? 'ON' : 'OFF',
                    color: isValveOn ? AppColors.danger : AppColors.success,
                    fontSize: 10,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
