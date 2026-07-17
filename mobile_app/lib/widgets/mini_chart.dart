import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/reading.dart';

class MiniChart extends StatelessWidget {
  final List<Reading> readings;
  const MiniChart({super.key, required this.readings});

  @override
  Widget build(BuildContext context) {
    final ordered = readings.reversed.toList();
    final spots = ordered.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.moisturePercent);
    }).toList();

    final values = readings.map((r) => r.moisturePercent);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        minY: (minY - 5).clamp(0, 100),
        maxY: (maxY + 5).clamp(0, 100),
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 2,
            color: Colors.green,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}
