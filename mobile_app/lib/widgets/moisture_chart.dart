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
      return const Center(child: Text('Belum ada data'));
    }

    // Balik urutan (dari terlama ke terbaru) untuk chart
    final sorted = data.reversed.toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey[200]!,
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
              reservedSize: 36,
              interval: 20,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}%',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (sorted.length / 5).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt().clamp(0, sorted.length - 1);
                final date = sorted[idx].createdAt;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 9, color: Colors.grey[500]),
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

        // Threshold lines
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: thresholdDry.toDouble(),
              color: Colors.red.withOpacity(0.4),
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
              color: Colors.blue.withOpacity(0.4),
              strokeWidth: 1,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(left: 4),
                labelResolver: (_) => 'Basah $thresholdWet%',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blue[300],
                ),
              ),
            ),
          ],
        ),

        // Main line
        lineBarsData: [
          LineChartBarData(
            spots: sorted.asMap().entries.map((e) =>
                FlSpot(e.key.toDouble(), e.value.moisturePercent)).toList(),
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppColors.primaryGreen,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primaryGreen.withOpacity(0.08),
            ),
          ),
        ],

        // Touch tooltips
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
