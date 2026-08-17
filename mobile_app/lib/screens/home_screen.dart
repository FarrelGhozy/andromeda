import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/devices_provider.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/offline_banner.dart';
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
            SizedBox(width: 8),
            const Text('ANDROMEDA'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, AppRoutes.settings);
            },
            tooltip: 'Pengaturan',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.read<DevicesProvider>().refreshReadings();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer2<DevicesProvider, ConnectivityProvider>(
        builder: (context, provider, connectivity, _) {
          return Column(
            children: [
              // Fase 0 — peringatan offline di homepage.
              if (connectivity.isOffline)
                OfflineBanner(cachedAt: provider.cachedAt),
              Expanded(
                child: _buildContent(context, provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, DevicesProvider provider) {
    if (provider.isLoading) {
      return ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 3,
        itemBuilder: (_, __) => const ShimmerDeviceCard(),
      );
    }

    if (provider.error != null) {
      return ErrorBanner(
        message: provider.error!,
        onRetry: provider.refreshReadings,
      );
    }

    final esp32Ids = provider.esp32Ids;
    if (esp32Ids.isEmpty) {
      return _buildEmptyState(context, provider);
    }

    return RefreshIndicator(
      onRefresh: provider.refreshReadings,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        // index 0 = menu fitur (cuaca), sisanya daftar lahan.
        itemCount: esp32Ids.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _WeatherMenuCard(),
            );
          }
          final esp32Id = esp32Ids[index - 1];
          final devices = provider.devicesForEsp32(esp32Id);
          final onlineCount = provider.onlineCountForEsp32(esp32Id);
          final totalCount = devices.length;
          final location = devices.isNotEmpty ? devices.first.location : '';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _Esp32Card(
              esp32Id: esp32Id,
              location: location,
              onlineCount: onlineCount,
              totalCount: totalCount,
              showSavedBadge: context.watch<ConnectivityProvider>().isOffline,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(
                  context,
                  AppRoutes.esp32Detail,
                  arguments: esp32Id,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DevicesProvider provider) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sensors_off,
              size: 80,
              // Fix #27: warna adaptif terhadap tema.
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('Belum ada ESP32 terdaftar',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Pastikan ESP32 sudah terhubung\ndan terdaftar di database',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.refreshReadings();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu menu fitur — entry point ke halaman Cuaca (Fase 1).
/// Fase 2/3 akan menambah menu Jurnal & Rekapan di sini.
class _WeatherMenuCard extends StatelessWidget {
  const _WeatherMenuCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(context, AppRoutes.weather);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wb_sunny,
                    color: AppColors.accentOrange, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cuaca', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Prakiraan 7 hari & rekomendasi irigasi untuk lahan Anda',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Esp32Card extends StatelessWidget {
  final String esp32Id;
  final String location;
  final int onlineCount;
  final int totalCount;
  final bool showSavedBadge;
  final VoidCallback onTap;

  const _Esp32Card({
    required this.esp32Id,
    required this.location,
    required this.onlineCount,
    required this.totalCount,
    this.showSavedBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
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
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.memory,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(esp32Id, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      location,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
                        if (showSavedBadge) ...[
                          const SizedBox(width: 8),
                          _miniBadge(
                            'Data tersimpan',
                            AppColors.warning,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
