import 'package:flutter/material.dart';
import 'package:moliseis/utils/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CustomPulseEffect extends PaintingEffect {
  const CustomPulseEffect({
    super.lowerBound,
    super.upperBound,
    super.duration = const Duration(milliseconds: 1000),
    required this.context,
    this.customColor,
  }) : super(reverse: true);

  final BuildContext context;
  final Color? customColor;

  @override
  Paint createPaint(double t, Rect rect, TextDirection? textDirection) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    HSVColor? color2;

    if (customColor != null) {
      color2 = HSVColor.lerp(
        HSVColor.fromColor(customColor.darken(0.05)!),
        HSVColor.fromColor(customColor.darken(0.12)!),
        t,
      );
    } else {
      color2 = HSVColor.lerp(
        HSVColor.fromColor(colorScheme.surfaceContainerHigh),
        HSVColor.fromColor(colorScheme.surfaceContainerLow),
        t,
      );
    }

    return Paint()
      ..shader = LinearGradient(
        colors: [color2!.toColor(), color2.toColor()],
      ).createShader(rect);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomPulseEffect &&
          runtimeType == other.runtimeType &&
          duration == other.duration &&
          context == other.context;

  @override
  int get hashCode => duration.hashCode ^ context.hashCode;

  @override
  PaintingEffect lerp(PaintingEffect? other, double t) =>
      other is CustomPulseEffect
      ? CustomPulseEffect(duration: other.duration, context: context)
      : this;
}
