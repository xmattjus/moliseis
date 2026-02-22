import 'package:flutter/material.dart';

/// Source: https://stackoverflow.com/a/79555444
class PulsePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  PulsePainter({required this.animation, this.color = Colors.purple})
    : super(repaint: animation);

  void drawPulse(Canvas canvas, Rect rect, double value) {
    final double opacity = (1.0 - value).clamp(0, 1.0);
    final Color colorWithOpacity = color.withValues(alpha: opacity);

    final Paint paint = Paint()..color = colorWithOpacity;

    final maxSide = rect.longestSide;
    final minSide = rect.shortestSide;
    final aspectRatio = rect.width / rect.height;

    // Empiric values, can be adjusted
    final scaleFactorHelper = maxSide > 150 ? 0.2 : 0.3;
    final scaleFactor = 1.0 + (value * scaleFactorHelper);

    double width = 0;
    double height = 0;

    // using the proportion of the smaller side so it does not go crazy
    // for bigger proportions (button, eg)
    if (aspectRatio > 1) {
      height = minSide * scaleFactor;
      final differenceHeight = height - rect.height;
      width = rect.width + differenceHeight;
    } else {
      width = minSide * scaleFactor;
      final differenceWidth = width - rect.width;
      height = rect.height + differenceWidth;
    }

    final Rect scaledRect = Rect.fromCenter(
      center: rect.center,
      width: width,
      height: height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, const Radius.circular(10)),
      paint,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTRB(0.0, 0.0, size.width, size.height);

    drawPulse(canvas, rect, animation.value);
  }

  @override
  bool shouldRepaint(PulsePainter oldDelegate) {
    return true;
  }
}
