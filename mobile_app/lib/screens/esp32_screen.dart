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
    final theme = Theme.of(context);
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
                style: theme.textTheme.bodyMedium?.copyWith(
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
                  StatusBadge(
                    text: isOnline ? 'Online' : 'Offline',
                    color: isOnline ? AppColors.success : AppColors.offline,
                    fontSize: 10,
                  ),
                  const SizedBox(width: 4),
                  StatusBadge(
                    text: isValveOn ? 'ON' : 'OFF',
                    color: isValveOn ? AppColors.success : AppColors.offline,
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
}
