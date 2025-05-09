import 'package:flutter/material.dart';

// TODO(xmattjus): phase out Pad, use Padding.
class Pad extends StatelessWidget {
  /// Creates a widget that insets its child.
  const Pad({
    super.key,
    this.s,
    this.t,
    this.e,
    this.b,
    this.h,
    this.v,
    required this.child,
  });

  /// Start.
  final double? s;

  /// Top.
  final double? t;

  /// End.
  final double? e;

  /// Bottom.
  final double? b;

  /// Horizontal (start and end).
  final double? h;

  /// Vertical (top and bottom).
  final double? v;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (h != null && (s != null || e != null)) {
      throw ArgumentError.value(
        h,
        'h, s and e != null. Assign only the first or the latter.',
      );
    }

    if (v != null && (t != null || b != null)) {
      throw ArgumentError.value(
        v,
        'v, t and b != null. Assign only the first or the latter.',
      );
    }

    final padding = EdgeInsetsDirectional.fromSTEB(
      h ?? s ?? 0,
      v ?? t ?? 0,
      h ?? e ?? 0,
      v ?? b ?? 0,
    );

    return Padding(padding: padding, child: child);
  }
}
