import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/devices_provider.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/offline_banner.dart';
import '../widgets/summary_cards.dart';
import '../widgets/summary_chart.dart';
import '../routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.water_drop_rounded,
                size: 23,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ANDROMEDA',
                  style: theme.textTheme.titleMedium?.copyWith(
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Pusat kendali lahan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.read<DevicesProvider>().refreshReadings();
            },
            tooltip: 'Perbarui data',
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, AppRoutes.settings);
            },
            tooltip: 'Pengaturan',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Consumer2<DevicesProvider, ConnectivityProvider>(
        builder: (context, provider, connectivity, _) {
          return Column(
            children: [
              if (connectivity.isOffline)
                OfflineBanner(cachedAt: provider.cachedAt),
              Expanded(
                child: _buildContent(
                  context,
                  provider,
                  isOffline: connectivity.isOffline,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DevicesProvider provider, {
    required bool isOffline,
  }) {
    if (provider.isLoading) {
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => const ShimmerDeviceCard(),
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

    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: provider.refreshReadings,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader(
            title: 'Kondisi lahan',
            subtitle:
                isOffline
                    ? 'Menampilkan data terakhir yang tersimpan'
                    : 'Status seluruh petak saat ini',
          ),
          const SizedBox(height: 10),
          const SummarySection(showTitle: false),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Akses cepat',
            subtitle: 'Informasi pendukung kegiatan di lahan',
          ),
          const SizedBox(height: 10),
          const _QuickActions(),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Perangkat lahan',
            subtitle: '${esp32Ids.length} unit pengendali terdaftar',
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < esp32Ids.length; index++) ...[
            Builder(
              builder: (context) {
                final esp32Id = esp32Ids[index];
                final devices = provider.devicesForEsp32(esp32Id);
                final onlineCount = provider.onlineCountForEsp32(esp32Id);
                final totalCount = devices.length;
                final location =
                    devices.isNotEmpty ? devices.first.location.trim() : '';
                return _Esp32Card(
                  esp32Id: esp32Id,
                  location: location.isEmpty ? 'Lokasi belum diatur' : location,
                  onlineCount: onlineCount,
                  totalCount: totalCount,
                  showSavedBadge: isOffline,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(
                      context,
                      AppRoutes.esp32Detail,
                      arguments: esp32Id,
                    );
                  },
                );
              },
            ),
            if (index != esp32Ids.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Analisis kelembaban',
            subtitle: 'Bandingkan kondisi antarpetak',
            trailing: Icon(
              Icons.bar_chart_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          const SummaryChart(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DevicesProvider provider) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sensors_off_rounded,
                size: 46,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text('Belum ada perangkat', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Pastikan ESP32 sudah menyala dan terdaftar di sistem, lalu '
              'coba perbarui data.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.refreshReadings();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Perbarui Data'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    const weather = _QuickActionCard(
      icon: Icons.wb_cloudy_rounded,
      color: AppColors.accentOrange,
      title: 'Cuaca',
      subtitle: 'Prakiraan 7 hari',
      route: AppRoutes.weather,
    );
    const journal = _QuickActionCard(
      icon: Icons.menu_book_rounded,
      color: AppColors.accentBlue,
      title: 'Jurnal',
      subtitle: 'Catat kegiatan',
      route: AppRoutes.journal,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return const Column(
            children: [weather, SizedBox(height: 10), journal],
          );
        }
        return const Row(
          children: [
            Expanded(child: weather),
            SizedBox(width: 10),
            Expanded(child: journal),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String route;

  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(context, route);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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
    final isHealthy = totalCount > 0 && onlineCount == totalCount;
    return Semantics(
      button: true,
      label: '$esp32Id, $location, $onlineCount dari $totalCount petak online',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.developer_board_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              esp32Id,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  isHealthy
                                      ? AppColors.success
                                      : (onlineCount > 0
                                          ? AppColors.warning
                                          : AppColors.offline),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MiniBadge(
                            text: '$onlineCount/$totalCount online',
                            color:
                                onlineCount > 0
                                    ? AppColors.success
                                    : AppColors.offline,
                          ),
                          _MiniBadge(
                            text: '$totalCount petak',
                            color: AppColors.accentBlue,
                          ),
                          if (showSavedBadge)
                            const _MiniBadge(
                              text: 'Data tersimpan',
                              color: AppColors.warning,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
