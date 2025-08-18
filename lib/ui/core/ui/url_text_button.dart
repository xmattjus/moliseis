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
      style: CustomButtonStyles.url(
        textStyle?.copyWith(color: foregroundColor),
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
}
