import 'dart:math';

import 'package:flutter/material.dart';

const _kWarningColor = Color(0xFFFF9F0A);

class PhaseRing extends StatelessWidget {
  const PhaseRing({
    super.key,
    required this.progress,
    required this.phaseColor,
    required this.isWarning,
    required this.size,
    required this.child,
  });

  final double progress;
  final Color phaseColor;
  final bool isWarning;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _PhaseRingPainter(
          progress: progress.clamp(0.0, 1.0),
          isWarning: isWarning,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _PhaseRingPainter extends CustomPainter {
  _PhaseRingPainter({required this.progress, required this.isWarning});

  final double progress;
  final bool isWarning;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;
    const strokeWidth = 10.0;
    const startAngle = -pi / 2;

    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final arcPaint = Paint()
      ..color = isWarning ? _kWarningColor : Colors.white
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_PhaseRingPainter old) =>
      old.progress != progress || old.isWarning != isWarning;
}
