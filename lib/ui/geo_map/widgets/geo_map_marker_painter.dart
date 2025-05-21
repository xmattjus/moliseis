import 'package:flutter/material.dart';

class GeoMapMarkerPainter extends CustomPainter {
  const GeoMapMarkerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..lineTo(size.width / 2, 0)
      ..cubicTo(
        size.width * 0.22,
        0,
        0,
        size.height * 0.15,
        0,
        size.height * 0.34,
      )
      ..cubicTo(
        0,
        size.height * 0.4,
        size.width * 0.03,
        size.height * 0.47,
        size.width * 0.14,
        size.height * 0.6,
      )
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.69,
        size.width * 0.38,
        size.height * 0.89,
        size.width * 0.46,
        size.height * 0.98,
      )
      ..cubicTo(
        size.width * 0.48,
        size.height,
        size.width * 0.52,
        size.height,
        size.width * 0.54,
        size.height * 0.98,
      )
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.89,
        size.width * 0.78,
        size.height * 0.69,
        size.width * 0.86,
        size.height * 0.6,
      )
      ..cubicTo(
        size.width * 0.97,
        size.height * 0.47,
        size.width,
        size.height * 0.4,
        size.width,
        size.height * 0.34,
      )
      ..cubicTo(
        size.width,
        size.height * 0.15,
        size.width * 0.78,
        0,
        size.width / 2,
        0,
      )
      ..cubicTo(size.width / 2, 0, size.width / 2, 0, size.width / 2, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    oldDelegate as GeoMapMarkerPainter;
    return oldDelegate.color != color;
  }
}
