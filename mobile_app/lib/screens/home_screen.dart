import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/devices_provider.dart';
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

          final esp32Ids = provider.esp32Ids;
          if (esp32Ids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sensors_off,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Belum ada ESP32 terdaftar',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.refreshReadings,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: esp32Ids.length,
              itemBuilder: (context, index) {
                final esp32Id = esp32Ids[index];
                final devices = provider.devicesForEsp32(esp32Id);
                final onlineCount = provider.onlineCountForEsp32(esp32Id);
                final totalCount = devices.length;
                final location = devices.isNotEmpty ? devices.first.location : '';

                return _Esp32Card(
                  esp32Id: esp32Id,
                  location: location,
                  onlineCount: onlineCount,
                  totalCount: totalCount,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.esp32Detail,
                    arguments: esp32Id,
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

class _Esp32Card extends StatelessWidget {
  final String esp32Id;
  final String location;
  final int onlineCount;
  final int totalCount;
  final VoidCallback onTap;

  const _Esp32Card({
    required this.esp32Id,
    required this.location,
    required this.onlineCount,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.memory,
                  color: AppColors.primaryGreen,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esp32Id,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _miniBadge(
                          '$onlineCount/$totalCount Online',
                          onlineCount > 0
                              ? AppColors.success
                              : AppColors.offline,
                        ),
                        const SizedBox(width: 8),
                        _miniBadge(
                          '$totalCount Petak',
                          AppColors.accentBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
