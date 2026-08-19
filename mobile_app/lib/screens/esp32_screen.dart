import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/devices_provider.dart';
import '../providers/connectivity_provider.dart';
import '../models/device.dart';
import '../models/sensor_reading.dart';
import '../widgets/moisture_gauge.dart';
import '../widgets/rename_petak_dialog.dart';
import '../widgets/offline_banner.dart';
import '../routes.dart';

class Esp32Screen extends StatelessWidget {
  final String esp32Id;

  const Esp32Screen({super.key, required this.esp32Id});

  Future<void> _renamePetak(
    BuildContext context,
    DevicesProvider provider,
    Device device,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showRenamePetakDialog(
      context,
      deviceId: device.deviceId,
      currentName: device.name,
      onRename: (name) => provider.renameDevice(device.deviceId, name),
    );
    if (!saved || !context.mounted) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Nama petak berhasil diubah'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Petak Lahan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Perbarui data',
            onPressed: () {
              HapticFeedback.lightImpact();
              context.read<DevicesProvider>().refreshReadings();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Consumer2<DevicesProvider, ConnectivityProvider>(
        builder: (context, provider, connectivity, _) {
          final devices = provider.devicesForEsp32(esp32Id);
          return Column(
            children: [
              if (connectivity.isOffline)
                OfflineBanner(cachedAt: provider.cachedAt),
              Expanded(
                child:
                    devices.isEmpty
                        ? _EmptyPetak(onRetry: provider.refreshReadings)
                        : LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildContent(
                              context,
                              provider,
                              devices,
                              isOffline: connectivity.isOffline,
                              width: constraints.maxWidth,
                            );
                          },
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
    DevicesProvider provider,
    List<Device> devices, {
    required bool isOffline,
    required double width,
  }) {
    final onlineCount = provider.onlineCountForEsp32(esp32Id);
    final valveOpenCount =
        devices.where((device) {
          final reading = provider.latestFor(device.deviceId);
          return provider.isDeviceOnline(device.deviceId) &&
              reading?.isValveOpen == true;
        }).length;
    final location = devices.first.location.trim();
    final isPhone = width < 600;
    final columns = width < 900 ? 2 : 3;

    Widget buildCard(Device device) {
      final reading = provider.latestFor(device.deviceId);
      final isOnline = provider.isDeviceOnline(device.deviceId);
      return _PetakCard(
        device: device,
        reading: reading,
        isOnline: isOnline,
        showSavedStatus: isOffline,
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
    }

    return RefreshIndicator(
      onRefresh: provider.refreshReadings,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _DeviceOverviewCard(
                esp32Id: esp32Id,
                location: location.isEmpty ? 'Perangkat irigasi' : location,
                totalCount: devices.length,
                onlineCount: onlineCount,
                valveOpenCount: valveOpenCount,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            sliver: SliverToBoxAdapter(
              child: _SectionHeader(totalCount: devices.length),
            ),
          ),
          if (isPhone)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index == devices.length - 1 ? 0 : 10,
                    ),
                    child: buildCard(devices[index]),
                  ),
                  childCount: devices.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 132,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => buildCard(devices[index]),
                  childCount: devices.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceOverviewCard extends StatelessWidget {
  final String esp32Id;
  final String location;
  final int totalCount;
  final int onlineCount;
  final int valveOpenCount;

  const _DeviceOverviewCard({
    required this.esp32Id,
    required this.location,
    required this.totalCount,
    required this.onlineCount,
    required this.valveOpenCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final allOnline = totalCount > 0 && onlineCount == totalCount;

    return Card(
      color: colors.primaryContainer.withValues(alpha: 0.68),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.developer_board_rounded,
                    color: colors.onPrimary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        esp32Id.toUpperCase(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onPrimaryContainer.withValues(
                            alpha: 0.7,
                          ),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                _HealthPill(
                  label: allOnline ? 'Sehat' : '$onlineCount online',
                  color: allOnline ? AppColors.success : AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: colors.onPrimaryContainer.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _OverviewStat(
                  icon: Icons.grid_view_rounded,
                  value: '$totalCount',
                  label: 'Petak',
                ),
                _OverviewDivider(color: colors.outlineVariant),
                _OverviewStat(
                  icon: Icons.wifi_tethering_rounded,
                  value: '$onlineCount/$totalCount',
                  label: 'Online',
                ),
                _OverviewDivider(color: colors.outlineVariant),
                _OverviewStat(
                  icon: Icons.water_drop_rounded,
                  value: '$valveOpenCount',
                  label: 'Valve aktif',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthPill extends StatelessWidget {
  final String label;
  final Color color;

  const _HealthPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _OverviewStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.72)),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withValues(alpha: 0.68),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewDivider extends StatelessWidget {
  final Color color;

  const _OverviewDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 48, child: VerticalDivider(width: 1, color: color));
  }
}

class _SectionHeader extends StatelessWidget {
  final int totalCount;

  const _SectionHeader({required this.totalCount});

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
              Text('Daftar petak', style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                'Ketuk kartu untuk melihat detail dan kontrol valve.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$totalCount petak',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PetakCard extends StatelessWidget {
  final Device device;
  final SensorReading? reading;
  final bool isOnline;
  final bool showSavedStatus;
  final VoidCallback onTap;
  final VoidCallback onRename;

  const _PetakCard({
    required this.device,
    required this.reading,
    required this.isOnline,
    required this.showSavedStatus,
    required this.onTap,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moisture = reading?.moisturePercent ?? 0.0;
    final hasFault = isOnline && reading?.isSensorFault == true;
    final isValveOpen = reading?.isValveOpen == true;
    final valveLabel =
        !isOnline
            ? 'Status valve tidak tersedia'
            : (isValveOpen ? 'Valve sedang terbuka' : 'Valve tertutup');
    final valveColor =
        !isOnline
            ? AppColors.offline
            : (isValveOpen
                ? AppColors.accentBlue
                : theme.colorScheme.onSurfaceVariant);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gaugeSize = constraints.maxWidth < 300 ? 72.0 : 82.0;
        return Semantics(
          button: true,
          label:
              '${device.name}, kelembaban ${moisture.round()} persen, '
              '${isOnline ? 'online' : 'offline'}, $valveLabel',
          child: Card(
            clipBehavior: Clip.antiAlias,
            color: isOnline ? null : theme.colorScheme.surfaceContainerLow,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 122),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      MoistureGauge(
                        percent: moisture,
                        size: gaugeSize,
                        greyedOut: !isOnline,
                        fault: hasFault,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    device.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                IconButton(
                                  onPressed: onRename,
                                  tooltip: 'Ganti nama petak',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor:
                                        theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                    foregroundColor:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: 38,
                                    minHeight: 38,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              _updatedLabel(reading?.createdAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _InlineStatus(
                              icon: Icons.circle,
                              label:
                                  isOnline
                                      ? 'Perangkat online'
                                      : 'Perangkat offline',
                              color:
                                  isOnline
                                      ? AppColors.success
                                      : AppColors.offline,
                              dotIcon: true,
                            ),
                            const SizedBox(height: 5),
                            _InlineStatus(
                              icon:
                                  isValveOpen
                                      ? Icons.water_drop_rounded
                                      : Icons.water_drop_outlined,
                              label: valveLabel,
                              color: valveColor,
                            ),
                            if (showSavedStatus) ...[
                              const SizedBox(height: 5),
                              const _InlineStatus(
                                icon: Icons.history_rounded,
                                label: 'Menampilkan data tersimpan',
                                color: AppColors.warning,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _updatedLabel(DateTime? updatedAt) {
    if (updatedAt == null) return 'Belum ada pembacaan sensor';
    final difference = DateTime.now().difference(updatedAt);
    if (difference.isNegative || difference.inMinutes < 1) {
      return 'Diperbarui baru saja';
    }
    if (difference.inMinutes < 60) {
      return 'Diperbarui ${difference.inMinutes} menit lalu';
    }
    if (difference.inHours < 24) {
      return 'Diperbarui ${difference.inHours} jam lalu';
    }
    final day = updatedAt.day.toString().padLeft(2, '0');
    final month = updatedAt.month.toString().padLeft(2, '0');
    final hour = updatedAt.hour.toString().padLeft(2, '0');
    final minute = updatedAt.minute.toString().padLeft(2, '0');
    return 'Data $day/$month pukul $hour:$minute';
  }
}

class _InlineStatus extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool dotIcon;

  const _InlineStatus({
    required this.icon,
    required this.label,
    required this.color,
    this.dotIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: dotIcon ? 8 : 15, color: color),
        SizedBox(width: dotIcon ? 8 : 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyPetak extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _EmptyPetak({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('Belum ada petak', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Petak yang terhubung ke unit ini belum tersedia.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Perbarui Data'),
            ),
          ],
        ),
      ),
    );
  }
}
