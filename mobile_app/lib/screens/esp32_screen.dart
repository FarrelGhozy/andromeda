import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/devices_provider.dart';
import '../models/device.dart';
import '../models/sensor_reading.dart';
import '../widgets/moisture_gauge.dart';
import '../widgets/rename_petak_dialog.dart';
import '../widgets/status_badge.dart';
import '../routes.dart';

class Esp32Screen extends StatelessWidget {
  final String esp32Id;
  const Esp32Screen({super.key, required this.esp32Id});

  /// Buka dialog ganti nama petak + feedback SnackBar.
  Future<void> _renamePetak(
      BuildContext context, DevicesProvider provider, Device device) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showRenamePetakDialog(
      context,
      deviceId: device.deviceId,
      currentName: device.name,
      onRename: (name) => provider.renameDevice(device.deviceId, name),
    );
    if (!saved) return;
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(
      content: Text('Nama petak diubah ✓'),
      backgroundColor: AppColors.success,
      duration: Duration(seconds: 3),
    ));
  }

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
                final isOnline = provider.isDeviceOnline(device.deviceId);
                return _PetakCard(
                  device: device,
                  reading: reading,
                  isOnline: isOnline,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(
                      context,
                      AppRoutes.dashboard,
                      arguments: device.deviceId,
                    );
                  },
                  onRename: () {
                    HapticFeedback.lightImpact();
                    _renamePetak(context, provider, device);
                  },
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
  final Device device;
  final SensorReading? reading;
  final bool isOnline;
  final VoidCallback onTap;
  final VoidCallback onRename;

  const _PetakCard({
    required this.device,
    required this.reading,
    required this.isOnline,
    required this.onTap,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moisture = reading?.moisturePercent ?? 0.0;
    final isValveOn = reading?.isValveOpen ?? false;

    return Card(
      color: isOnline ? null : theme.colorScheme.surfaceContainerLow,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MoistureGauge(
                    percent: moisture,
                    size: 100,
                    greyedOut: !isOnline,
                    fault: isOnline && reading?.isSensorFault == true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    device.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      // Fix #27: warna teks offline adaptif terhadap tema.
                      color: isOnline
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
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
                        color: isOnline
                            ? AppColors.success
                            : AppColors.offline,
                        fontSize: 10,
                      ),
                      const SizedBox(width: 4),
                      StatusBadge(
                        // Fix #16: data basi → status valve TIDAK DIKETAHUI,
                        // bukan "OFF" palsu.
                        // Fix #25: ON = hijau (aktif), OFF = netral, "—" = abu.
                        text: isOnline ? (isValveOn ? 'ON' : 'OFF') : '—',
                        color: !isOnline
                            ? AppColors.offline
                            : (isValveOn
                                ? AppColors.success
                                : theme.colorScheme.onSurfaceVariant),
                        fontSize: 10,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: Icon(
                Icons.edit,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Ganti nama petak',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
              onPressed: onRename,
            ),
          ),
        ],
      ),
    );
  }
}
