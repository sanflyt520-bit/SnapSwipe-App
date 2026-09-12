import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/daily_stats.dart';

/// 多邻国风格的每日进度环
///
/// 环内显示「今日已处理 / 配额」,达成配额后整环变金色,给一个明确的完成反馈。
class DailyProgressRing extends StatelessWidget {
  const DailyProgressRing({
    super.key,
    required this.stats,
    this.size = 62,
    this.strokeWidth = 6,
  });

  final DailyStats stats;
  final double size;
  final double strokeWidth;

  static const Color _progressColor = Color(0xFF34C759);
  static const Color _completedColor = Color(0xFFFFB800);
  static const Color _trackColor = Color(0xFFE8E8ED);

  @override
  Widget build(BuildContext context) {
    final done = stats.isQuotaReached;
    final color = done ? _completedColor : _progressColor;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: stats.progress,
          color: color,
          trackColor: _trackColor,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${stats.todayProcessed}',
                style: TextStyle(
                  color: done ? _completedColor : const Color(0xFF1C1C1E),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              Text(
                '/${stats.quota}',
                style: const TextStyle(
                  color: Color(0xFF8A8A8E),
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 底环
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // 进度弧:从 12 点方向顺时针
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
