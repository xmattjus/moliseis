import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/button_style.dart';

class UrlTextButton extends StatelessWidget {
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

  final void Function()? onPressed;
  final Widget? icon;
  final double? iconSize;
  final Widget label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    /// The color the map attribution icons and texts will have.
    final widgetColor =
        color ??
        Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7);

    /// The style the map attribution texts will have.
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: widgetColor);

    return TextButton.icon(
      onPressed: onPressed,
      style: CustomButtonStyles.url(textStyle, widgetColor),
      icon: IconTheme(
        data: IconThemeData(
          size: iconSize,
          color: widgetColor,
          applyTextScaling: false,
        ),
        child: icon ?? const SizedBox(),
      ),
      label: label,
    );
  }
}
