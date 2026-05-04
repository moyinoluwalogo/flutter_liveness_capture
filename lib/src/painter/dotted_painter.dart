import 'dart:math';
import 'package:flutter/material.dart';

/// A [CustomPainter] that draws a dotted ring around a circular face frame.
///
/// Dots are drawn evenly spaced around a circle. Dots from index 0 up to
/// `progress * totalDots` are painted with [activeProgressColor]; the rest
/// use [progressColor]. This creates a visual progress indicator that fills
/// clockwise as the user completes liveness challenges.
class DottedCirclePainter extends CustomPainter {
  /// Fraction of the ring to colour as active, in the range [0.0, 1.0].
  final double progress;

  /// Total number of dots drawn around the ring. Defaults to 60.
  final int totalDots;

  /// Radius of each individual dot in logical pixels. Defaults to 3.0.
  final double dotRadius;

  /// Color used for dots that represent completed progress.
  final Color? activeProgressColor;

  /// Color used for dots that represent remaining progress.
  final Color? progressColor;

  DottedCirclePainter({
    required this.progress,
    this.totalDots = 60,
    this.dotRadius = 3.0,
    this.activeProgressColor,
    this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double spacingOffset = dotRadius * 2;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) + spacingOffset;

    final Paint dotPaint = Paint()..style = PaintingStyle.fill;

    int greenDotsCount = (progress * totalDots).round();

    double normalSpacing = (2 * pi) / totalDots;

    double currentAngle = -pi / 2;

    for (int i = 0; i < totalDots; i++) {
      double x = center.dx + radius * cos(currentAngle);
      double y = center.dy + radius * sin(currentAngle);

      if (i < greenDotsCount) {
        dotPaint.color = activeProgressColor ?? Colors.green;
        canvas.drawCircle(Offset(x, y), dotRadius + 1.5, dotPaint);
      } else {
        dotPaint.color = progressColor ?? Colors.red;
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }

      currentAngle += normalSpacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
