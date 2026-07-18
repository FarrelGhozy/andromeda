import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/devices_provider.dart';
import '../widgets/device_card.dart';
import '../widgets/error_banner.dart';
import '../routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop_rounded, size: 24),
            const SizedBox(width: 8),
            const Text('ANDROMEDA'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.settings),
            tooltip: 'Pengaturan',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<DevicesProvider>().refreshReadings(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<DevicesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return ErrorBanner(
              message: provider.error!,
              onRetry: provider.refreshReadings,
            );
          }

          if (provider.devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sensors_off,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Belum ada device terdaftar',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.refreshReadings,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.devices.length,
              itemBuilder: (context, index) {
                final device = provider.devices[index];
                final reading = provider.latestFor(device.deviceId);
                return DeviceCard(
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
