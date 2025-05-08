import 'package:flutter/material.dart';

class CustomInkWell extends StatelessWidget {
  final void Function() onPressed;

  /// The shape of the [InkWell].
  ///
  /// Defines the [InkWell]'s [BoxShape].
  ///
  /// If this property is null then the shape will be a [RoundedRectangleBorder]
  /// with a circular corner radius of 12.0.
  final ShapeBorder? shape;

  /// Creates an ink well respecting the Material3 design guidelines.
  ///
  /// Must have an ancestor Material widget in which to cause ink reactions.
  const CustomInkWell({super.key, required this.onPressed, this.shape});

  @override
  Widget build(BuildContext context) {
    final boxShape =
        shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0));

    return InkWell(
      onTap: onPressed,
      overlayColor: WidgetStateProperty.resolveWith<Color?>((
        Set<WidgetState> states,
      ) {
        Color? color;

        if (states.contains(WidgetState.hovered)) {
          color = Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.08);
        }

        if (states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed)) {
          color = Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.10);
        }

        return color;
      }),
      customBorder: boxShape,
    );
  }
}
