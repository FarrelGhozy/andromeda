import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme_config.dart';
import '../models/sensor_reading.dart';

class MoistureChart extends StatelessWidget {
  final List<SensorReading> data;
  final int thresholdDry;
  final int thresholdWet;

  const MoistureChart({
    super.key,
    required this.data,
    this.thresholdDry = 30,
    this.thresholdWet = 70,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'Belum ada data',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    // Data dari repository sudah ascending (terlama → terbaru).
    // X-axis: selisih menit dari data pertama → jarak titik proporsional
    // dengan waktu nyata (bukan indeks array). (fix #4, #32)
    final sorted = data.toList();
    final t0 = sorted.first.createdAt;
    final totalMinutes = t0.difference(sorted.last.createdAt).inMinutes.abs();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            // Fix #27: warna grid adaptif terhadap tema.
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: totalMinutes.toDouble().clamp(1, double.infinity),
        minY: 0,
        maxY: 100,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 20,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (totalMinutes / 5).clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final t = t0.add(Duration(minutes: value.toInt()));
                // Range > 2 hari → sertakan tanggal agar tidak ambigu.
                final label = totalMinutes > 2 * 24 * 60
                    ? '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:'
                        '${t.minute.toString().padLeft(2, '0')}'
                    : '${t.hour.toString().padLeft(2, '0')}:'
                        '${t.minute.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),

        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: thresholdDry.toDouble(),
              color: Colors.red.withValues(alpha: 0.4),
              strokeWidth: 1,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(left: 4),
                labelResolver: (_) => 'Kering $thresholdDry%',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red[300],
                ),
              ),
            ),
            HorizontalLine(
              y: thresholdWet.toDouble(),
              color: Colors.blue.withValues(alpha: 0.4),
              strokeWidth: 1,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 4),
                labelResolver: (_) => 'Basah $thresholdWet%',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue[300],
                ),
              ),
            ),
          ],
        ),

        lineBarsData: [
          LineChartBarData(
            spots: sorted.map((r) => FlSpot(
                  t0.difference(r.createdAt).inMinutes.abs().toDouble(),
                  r.moisturePercent,
                )).toList(),
            // Fix #32: garis patah (bukan kurva) — tidak ada overshoot
            // interpolasi palsu pada data renggang/spike.
            isCurved: false,
            color: AppColors.primaryGreen,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
            ),
          ),
        ],

        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.primaryDark,
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots.map((s) =>
                LineTooltipItem(
                  '${s.y.toStringAsFixed(0)}%',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
            ).toList(),
          ),
        ),
      ),
    );
  }
}
