import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme_config.dart';

class MoistureGauge extends StatelessWidget {
  final double percent;
  final double size;
  final bool showLabel;
  final bool offline;
  final int thresholdDry;
  final int thresholdWet;

  const MoistureGauge({
    super.key,
    required this.percent,
    required this.size,
    this.showLabel = true,
    this.offline = false,
    this.thresholdDry = 30,
    this.thresholdWet = 70,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final label = _getLabel();

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(
          percent: offline ? 0 : (percent / 100).clamp(0.0, 1.0),
          color: color,
          backgroundColor: Colors.grey[200]!,
          strokeWidth: size * 0.12,
        ),
        child: showLabel
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      offline ? '—' : '${percent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: size * 0.28,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: size * 0.11,
                        color: offline ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  Color _getColor() {
    if (offline) return AppColors.offline;
    if (percent < thresholdDry) return AppColors.danger;
    if (percent < thresholdWet) return AppColors.warning;
    return AppColors.primaryGreen;
  }

  String _getLabel() {
    if (offline) return 'OFFLINE';
    if (percent < thresholdDry) return 'KERING';
    if (percent < thresholdWet) return 'LEMBAB';
    return 'BASAH';
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _GaugePainter({
    required this.percent,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (percent <= 0) return;

    // Foreground arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * percent;
    canvas.drawArc(rect, -pi / 2, sweepAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.percent != percent || old.color != color;
}
