import 'package:flutter/material.dart';

/// A widget that provides a linear gradient background transitioning from a
/// semi-transparent black color to full transparency, typically used in the
/// portion of the screen occupied by the system status and navigation bars.
/// It is used to improve system UI readability against a non-uniform background
/// (e.g. images or complex patterns).
class LinearGradientBackground extends StatelessWidget {
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final Widget child;

  const LinearGradientBackground({
    super.key,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: const <Color>[Colors.black54, Colors.transparent],
          begin: begin,
          end: end,
          stops: const [0, 1],
        ),
      ),
      child: child,
    );
  }
}
