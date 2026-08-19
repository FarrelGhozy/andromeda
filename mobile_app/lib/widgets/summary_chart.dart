import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme_config.dart';
import '../providers/devices_provider.dart';
import 'summary_cards.dart';

/// Grafik batang rata-rata kelembaban per petak (Fase 3).
/// Warna batang menandakan status:
/// - abu-abu: sensor error / tidak ada data segar
/// - oranye: kering (< 30%)
/// - hijau: normal (30–70%)
/// - biru: basah (> 70%)
class SummaryChart extends StatelessWidget {
  const SummaryChart({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DevicesProvider>();
    if (provider.devices.isEmpty) return const SizedBox.shrink();

    final stats = SummaryStats.fromProvider(provider);
    final petaks = stats.petaks;

    if (petaks.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kelembaban tiap petak', style: theme.textTheme.titleSmall),
            const SizedBox(height: 3),
            Text(
              'Geser grafik jika seluruh petak belum terlihat.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = math.max(
                  constraints.maxWidth,
                  petaks.length * 52.0,
                );
                return Semantics(
                  label: 'Grafik kelembaban ${petaks.length} petak',
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      height: 190,
                      child: BarChart(
                        BarChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 20,
                            getDrawingHorizontalLine:
                                (value) => FlLine(
                                  // Fix #27: warna grid adaptif terhadap tema.
                                  color: theme.colorScheme.outlineVariant,
                                  strokeWidth: 1,
                                ),
                          ),
                          borderData: FlBorderData(show: false),
                          minY: 0,
                          maxY: 100,
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32,
                                interval: 20,
                                getTitlesWidget:
                                    (value, meta) => Text(
                                      '${value.toInt()}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                              ),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  if (i < 0 || i >= petaks.length) {
                                    return const SizedBox.shrink();
                                  }
                                  // Nama petak dipotong agar tidak bertumpuk.
                                  final label = petaks[i].label
                                      .replaceAll('PETAK ', '')
                                      .replaceAll('Petak ', '');
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      label.length > 8
                                          ? '${label.substring(0, 7)}…'
                                          : label,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: [
                            for (var i = 0; i < petaks.length; i++)
                              BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY:
                                        petaks[i].fresh
                                            ? petaks[i].moisture
                                            : 0,
                                    width: 18,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                    color: _barColor(petaks[i]),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Legenda
            const Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _LegendDot(color: AppColors.success, label: 'Normal'),
                _LegendDot(color: AppColors.accentOrange, label: 'Kering'),
                _LegendDot(color: AppColors.accentBlue, label: 'Basah'),
                _LegendDot(color: AppColors.offline, label: 'Error/tidak ada'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _barColor(PetakMoisture p) {
    if (!p.fresh || p.fault) return AppColors.offline;
    if (p.moisture < 30) return AppColors.accentOrange;
    if (p.moisture > 70) return AppColors.accentBlue;
    return AppColors.success;
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
