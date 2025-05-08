import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/ui/url_text_button.dart';

class CustomButtonStyles {
  const CustomButtonStyles._();

  /// The [ButtonStyle] used by the app [UrlTextButton].
  static ButtonStyle url(TextStyle? textStyle, Color? color) {
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
