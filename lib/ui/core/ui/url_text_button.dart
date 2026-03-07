import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/button_styles.dart';
import 'package:moliseis/ui/core/ui/empty_box.dart';

class UrlTextButton extends StatelessWidget {
  final void Function()? onPressed;
  final Widget? icon;
  final double? iconSize;
  final Widget label;
  final Color? color;

  /// Creates a Material [TextButton] with a fixed style appropriate for
  /// launching URLs external to the app.
  const UrlTextButton({
    super.key,
    this.onPressed,
    required this.label,
    this.color,
  }) : icon = null,
       iconSize = null;

  /// Creates a Material [TextButton.icon] with a fixed style appropriate for
  /// launching URLs external to the app.
  const UrlTextButton.icon({
    super.key,
    this.onPressed,
    this.iconSize,
    this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall;
    // The color the map attribution icons and texts will have.
    final foregroundColor = color ?? textStyle?.color?.withValues(alpha: 0.7);

    return TextButton.icon(
      onPressed: onPressed,
      style: _buttonStyle(
        textStyle?.copyWith(
          color: foregroundColor,
          decoration: TextDecoration.underline,
        ),
        foregroundColor,
      ),
      icon: IconTheme(
        data: IconThemeData(
          size: iconSize,
          color: foregroundColor,
          applyTextScaling: false,
        ),
        child: icon ?? const EmptyBox(),
      ),
      label: label,
    );
  }

  ButtonStyle _buttonStyle(TextStyle? textStyle, Color? color) {
    return ButtonStyle(
      textStyle: WidgetStatePropertyAll<TextStyle?>(textStyle),
      foregroundColor: WidgetStatePropertyAll<Color?>(color),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        Color? overlayColor;
        if (states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed)) {
          overlayColor = color?.withValues(alpha: 0.10);
        } else if (states.contains(WidgetState.hovered)) {
          overlayColor = color?.withValues(alpha: 0.08);
        }

        return overlayColor;
      }),
      iconColor: WidgetStatePropertyAll<Color?>(color),
      padding: const WidgetStatePropertyAll<EdgeInsets>(EdgeInsets.zero),
      minimumSize: const WidgetStatePropertyAll<Size>(Size.zero),
      // visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
