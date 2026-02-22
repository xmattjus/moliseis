import 'package:flutter/foundation.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AppPulseEffect extends PaintingEffect {
  final Color? from;
  final Color? to;
  final Color? color;

  const AppPulseEffect({
    this.from,
    this.to,
    this.color,
    super.lowerBound,
    super.upperBound,
    super.duration = const Duration(milliseconds: 1000),
  }) : assert(
         (from != null && to != null && color == null) ||
             (from == null && to == null && color != null),
         'Either declare both `from` and `to` or only `color`.',
       ),
       super(reverse: true);

  @override
  Paint createPaint(double t, Rect rect, TextDirection? textDirection) {
    Color color2;

    if (color != null) {
      color2 = HSVColor.lerp(
        HSVColor.fromColor(color.darken(0.05)!),
        HSVColor.fromColor(color.darken(0.12)!),
        t,
      )!.toColor();
    } else {
      color2 = HSVColor.lerp(
        HSVColor.fromColor(from!),
        HSVColor.fromColor(to!),
        t,
      )!.toColor();
    }

    // We're creating a shader here because [ShadedElement] component
    // will use a shader mask to shade original elements
    //
    // TODO(xmattjus): find a better way to create a one-color shader!
    return Paint()
      ..shader = LinearGradient(colors: [color2, color2]).createShader(rect);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppPulseEffect &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to &&
          color == other.color &&
          duration == other.duration;

  @override
  int get hashCode =>
      from.hashCode ^ to.hashCode ^ color.hashCode ^ duration.hashCode;

  @override
  PaintingEffect lerp(PaintingEffect? other, double t) {
    if (other is! AppPulseEffect) {
      return this;
    }

    return AppPulseEffect(
      from: Color.lerp(from, other.from, t),
      to: Color.lerp(to, other.to, t),
      color: Color.lerp(color, other.color, t),
      duration: lerpDuration(duration, other.duration, t),
    );
  }
}
