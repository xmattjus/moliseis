import 'package:flutter/material.dart';

class MountainsPathPainter extends CustomPainter {
  const MountainsPathPainter({
    required this.gradientBottomColor,
    required this.gradientTopColor,
  });

  /// The color used at the start (bottom) of the [LinearGradient].
  final Color gradientBottomColor;

  /// The color used at the end (top) of the [LinearGradient].
  final Color gradientTopColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.45);
    path.cubicTo(
      size.width * 0.02,
      size.height * 0.51,
      size.width * 0.05,
      size.height * 0.56,
      size.width * 0.07,
      size.height * 0.61,
    );
    path.cubicTo(
      size.width * 0.08,
      size.height * 0.57,
      size.width * 0.08,
      size.height * 0.53,
      size.width * 0.09,
      size.height * 0.47,
    );
    path.cubicTo(
      size.width * 0.09,
      size.height * 0.47,
      size.width * 0.09,
      size.height * 0.47,
      size.width * 0.1,
      size.height * 0.45,
    );
    path.cubicTo(
      size.width * 0.1,
      size.height * 0.45,
      size.width * 0.12,
      size.height * 0.48,
      size.width * 0.12,
      size.height * 0.48,
    );
    path.cubicTo(
      size.width * 0.12,
      size.height * 0.48,
      size.width * 0.13,
      size.height * 0.32,
      size.width * 0.13,
      size.height * 0.32,
    );
    path.cubicTo(
      size.width * 0.14,
      size.height * 0.3,
      size.width * 0.14,
      size.height * 0.29,
      size.width * 0.14,
      size.height / 4,
    );
    path.cubicTo(
      size.width * 0.15,
      size.height * 0.22,
      size.width * 0.15,
      size.height * 0.17,
      size.width * 0.16,
      size.height * 0.12,
    );
    path.cubicTo(
      size.width * 0.16,
      size.height * 0.11,
      size.width / 5,
      size.height * 0.29,
      size.width * 0.22,
      size.height / 3,
    );
    path.cubicTo(
      size.width * 0.22,
      size.height / 3,
      size.width / 4,
      size.height * 0.34,
      size.width / 4,
      size.height * 0.34,
    );
    path.cubicTo(
      size.width * 0.26,
      size.height * 0.37,
      size.width / 4,
      size.height / 3,
      size.width * 0.27,
      size.height * 0.32,
    );
    path.cubicTo(
      size.width * 0.28,
      size.height * 0.29,
      size.width * 0.28,
      size.height * 0.29,
      size.width * 0.29,
      size.height * 0.29,
    );
    path.cubicTo(
      size.width * 0.29,
      size.height * 0.29,
      size.width * 0.3,
      size.height * 0.26,
      size.width * 0.3,
      size.height * 0.26,
    );
    path.cubicTo(
      size.width * 0.31,
      size.height * 0.28,
      size.width * 0.32,
      size.height * 0.27,
      size.width / 3,
      size.height * 0.3,
    );
    path.cubicTo(
      size.width / 3,
      size.height * 0.3,
      size.width * 0.34,
      size.height * 0.27,
      size.width * 0.34,
      size.height * 0.27,
    );
    path.cubicTo(
      size.width * 0.36,
      size.height * 0.24,
      size.width * 0.35,
      size.height * 0.29,
      size.width * 0.37,
      size.height * 0.28,
    );
    path.cubicTo(
      size.width * 0.38,
      size.height * 0.32,
      size.width * 0.39,
      size.height * 0.28,
      size.width * 0.39,
      size.height * 0.32,
    );
    path.cubicTo(
      size.width * 0.4,
      size.height / 3,
      size.width * 0.41,
      size.height * 0.35,
      size.width * 0.41,
      size.height * 0.37,
    );
    path.cubicTo(
      size.width * 0.41,
      size.height * 0.39,
      size.width * 0.42,
      size.height * 0.36,
      size.width * 0.42,
      size.height * 0.42,
    );
    path.cubicTo(
      size.width * 0.43,
      size.height * 0.46,
      size.width * 0.43,
      size.height * 0.47,
      size.width * 0.44,
      size.height * 0.48,
    );
    path.cubicTo(
      size.width * 0.44,
      size.height / 2,
      size.width * 0.44,
      size.height * 0.51,
      size.width * 0.44,
      size.height * 0.51,
    );
    path.cubicTo(
      size.width * 0.45,
      size.height * 0.49,
      size.width * 0.45,
      size.height * 0.45,
      size.width * 0.46,
      size.height * 0.43,
    );
    path.cubicTo(
      size.width * 0.46,
      size.height * 0.45,
      size.width * 0.46,
      size.height * 0.45,
      size.width * 0.46,
      size.height * 0.44,
    );
    path.cubicTo(
      size.width * 0.47,
      size.height * 0.47,
      size.width * 0.47,
      size.height * 0.45,
      size.width * 0.48,
      size.height * 0.43,
    );
    path.cubicTo(
      size.width * 0.49,
      size.height * 0.46,
      size.width * 0.49,
      size.height * 0.47,
      size.width / 2,
      size.height * 0.46,
    );
    path.cubicTo(
      size.width * 0.51,
      size.height * 0.42,
      size.width * 0.51,
      size.height * 0.38,
      size.width * 0.52,
      size.height * 0.37,
    );
    path.cubicTo(
      size.width * 0.52,
      size.height * 0.37,
      size.width * 0.53,
      size.height * 0.31,
      size.width * 0.53,
      size.height * 0.31,
    );
    path.cubicTo(
      size.width * 0.53,
      size.height * 0.31,
      size.width * 0.54,
      size.height * 0.26,
      size.width * 0.54,
      size.height * 0.26,
    );
    path.cubicTo(
      size.width * 0.54,
      size.height / 4,
      size.width * 0.55,
      size.height * 0.16,
      size.width * 0.55,
      size.height * 0.14,
    );
    path.cubicTo(
      size.width * 0.56,
      size.height * 0.15,
      size.width * 0.56,
      size.height * 0.15,
      size.width * 0.57,
      size.height * 0.16,
    );
    path.cubicTo(
      size.width * 0.57,
      size.height * 0.17,
      size.width * 0.58,
      size.height * 0.16,
      size.width * 0.59,
      size.height * 0.15,
    );
    path.cubicTo(
      size.width * 0.62,
      size.height * 0.11,
      size.width * 0.65,
      size.height * 0.07,
      size.width * 0.68,
      size.height * 0.01,
    );
    path.cubicTo(
      size.width * 0.68,
      size.height * 0.01,
      size.width * 0.69,
      0,
      size.width * 0.69,
      0,
    );
    path.cubicTo(
      size.width * 0.7,
      size.height * 0.02,
      size.width * 0.7,
      size.height * 0.01,
      size.width * 0.71,
      0,
    );
    path.cubicTo(
      size.width * 0.71,
      0,
      size.width * 0.73,
      size.height * 0.02,
      size.width * 0.73,
      size.height * 0.02,
    );
    path.cubicTo(
      size.width * 0.74,
      size.height * 0.07,
      size.width * 0.75,
      size.height * 0.16,
      size.width * 0.77,
      size.height * 0.17,
    );
    path.cubicTo(
      size.width * 0.77,
      size.height * 0.17,
      size.width * 0.79,
      size.height * 0.27,
      size.width * 0.79,
      size.height * 0.27,
    );
    path.cubicTo(
      size.width * 0.8,
      size.height * 0.29,
      size.width * 0.8,
      size.height * 0.27,
      size.width * 0.81,
      size.height * 0.32,
    );
    path.cubicTo(
      size.width * 0.82,
      size.height * 0.36,
      size.width * 0.82,
      size.height * 0.35,
      size.width * 0.83,
      size.height * 0.38,
    );
    path.cubicTo(
      size.width * 0.86,
      size.height * 0.47,
      size.width * 0.84,
      size.height * 0.51,
      size.width * 0.87,
      size.height * 0.51,
    );
    path.cubicTo(
      size.width * 0.87,
      size.height * 0.47,
      size.width * 0.88,
      size.height * 0.48,
      size.width * 0.89,
      size.height * 0.49,
    );
    path.cubicTo(
      size.width * 0.89,
      size.height * 0.49,
      size.width * 0.9,
      size.height * 0.51,
      size.width * 0.9,
      size.height * 0.51,
    );
    path.cubicTo(
      size.width * 0.9,
      size.height * 0.45,
      size.width * 0.92,
      size.height * 0.48,
      size.width * 0.92,
      size.height * 0.48,
    );
    path.cubicTo(
      size.width * 0.95,
      size.height * 0.61,
      size.width * 0.97,
      size.height * 0.73,
      size.width,
      size.height * 0.85,
    );
    path.cubicTo(
      size.width,
      size.height * 0.85,
      size.width,
      size.height,
      size.width,
      size.height,
    );
    path.cubicTo(size.width, size.height, 0, size.height, 0, size.height);
    path.cubicTo(0, size.height, 0, size.height * 0.45, 0, size.height * 0.45);
    path.close();

    final rect = Offset.zero & size;
    final paintFill = Paint();
    paintFill.shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [gradientBottomColor, gradientTopColor],
    ).createShader(rect);
    canvas.drawPath(path, paintFill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    oldDelegate as MountainsPathPainter;
    return oldDelegate.gradientBottomColor != gradientBottomColor ||
        oldDelegate.gradientTopColor != gradientTopColor;
  }
}
