import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/devices_provider.dart';

/// Statistik ringkasan semua sensor — dihitung dari sumber tunggal
/// `DevicesProvider` (tidak ada query tambahan ke server).
/// Reading fault TIDAK ikut rata-rata; hanya reading fresh yang dihitung.
class SummaryStats {
  final int totalEsp32;
  final int totalPetak;
  final int onlinePetak;
  final double? avgMoisture;
  final int faultCount;
  final int valveOpenCount;
  final List<PetakMoisture> petaks;

  SummaryStats({
    required this.totalEsp32,
    required this.totalPetak,
    required this.onlinePetak,
    required this.avgMoisture,
    required this.faultCount,
    required this.valveOpenCount,
    required this.petaks,
  });

  static SummaryStats fromProvider(DevicesProvider p) {
    final devices = p.devices;
    double sum = 0;
    int n = 0;
    int fault = 0;
    int valveOpen = 0;
    final petaks = <PetakMoisture>[];

    for (final d in devices) {
      final r = p.latestFor(d.deviceId);
      final fresh =
          r != null &&
          DateTime.now().difference(r.createdAt) <=
              DevicesProvider.onlineWindow;
      if (r == null) {
        petaks.add(
          PetakMoisture(
            label: p.displayNameFor(d.deviceId),
            moisture: 0,
            fault: false,
            fresh: false,
          ),
        );
        continue;
      }
      final isFault = r.isSensorFault;
      if (isFault) fault++;
      if (fresh && !isFault) {
        sum += r.moisturePercent;
        n++;
      }
      if (fresh && r.isValveOpen) valveOpen++;
      petaks.add(
        PetakMoisture(
          label: p.displayNameFor(d.deviceId),
          moisture: r.moisturePercent,
          fault: isFault,
          fresh: fresh,
        ),
      );
    }

    return SummaryStats(
      totalEsp32: p.esp32Ids.length,
      totalPetak: devices.length,
      onlinePetak: devices.where((d) => p.isDeviceOnline(d.deviceId)).length,
      avgMoisture: n > 0 ? sum / n : null,
      faultCount: fault,
      valveOpenCount: valveOpen,
      petaks: petaks,
    );
  }
}

class PetakMoisture {
  final String label;
  final double moisture;
  final bool fault;
  final bool fresh;

  PetakMoisture({
    required this.label,
    required this.moisture,
    required this.fault,
    required this.fresh,
  });
}

/// Kartu ringkasan + grafik rekapan semua sensor — dipasang di halaman
/// utama (Fase 3).
class SummarySection extends StatelessWidget {
  final bool showTitle;

  const SummarySection({super.key, this.showTitle = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DevicesProvider>();
    if (provider.devices.isEmpty) return const SizedBox.shrink();

    final stats = SummaryStats.fromProvider(provider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Rekapan semua sensor',
              style: theme.textTheme.titleMedium,
            ),
          ),
        Card(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            child: Column(
              children: [
                Row(
                  children: [
                    _StatTile(
                      icon: Icons.sensors,
                      color: AppColors.accentBlue,
                      value: '${stats.totalPetak}',
                      label: 'Petak',
                    ),
                    SizedBox(
                      height: 48,
                      child: VerticalDivider(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    _StatTile(
                      icon: Icons.wifi_tethering,
                      color: AppColors.success,
                      value: '${stats.onlinePetak}/${stats.totalPetak}',
                      label: 'Online',
                    ),
                    SizedBox(
                      height: 48,
                      child: VerticalDivider(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    _StatTile(
                      icon: Icons.water_drop_outlined,
                      color: AppColors.primaryGreen,
                      value:
                          stats.avgMoisture != null
                              ? '${stats.avgMoisture!.toStringAsFixed(0)}%'
                              : '—',
                      label: 'Rata-rata',
                    ),
                  ],
                ),
                if (stats.faultCount > 0 || stats.valveOpenCount > 0) ...[
                  const SizedBox(height: 14),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (stats.faultCount > 0)
                        _miniChip(
                          Icons.error_outline,
                          '${stats.faultCount} sensor error',
                          AppColors.danger,
                        ),
                      if (stats.valveOpenCount > 0)
                        _miniChip(
                          Icons.water_drop,
                          '${stats.valveOpenCount} valve terbuka',
                          AppColors.success,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
