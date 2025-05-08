import 'package:flutter/material.dart';

class CustomRichText extends StatelessWidget {
  const CustomRichText(
    this.label, {
    super.key,
    this.labelTextStyle,
    this.icon,
    this.iconColor,
    this.content,
    this.contentTextStyle,
    this.maxLines = 1,
  });

  ///
  ///
  /// Typically a [Text] widget.
  final Widget label;

  /// Style for the text in the [label] of this [CustomRichText].
  ///
  /// If null, defaults to [TextTheme.bodyMedium] of [ThemeData.textTheme].
  final TextStyle? labelTextStyle;

  ///
  ///
  /// Typically an [Icon] widget.
  final Widget? icon;

  /// Color for the icon in the [icon] of this [CustomRichText].
  ///
  /// If null, [CustomRichText.labelTextStyle]'s color is used. If that's null,
  /// defaults to the color defined in [TextTheme.bodyMedium] of
  /// [ThemeData.textTheme]. If that's null, defaults to white if
  /// [ThemeData.brightness] is dark and black if
  /// [ThemeData.brightness] is light.
  final Color? iconColor;

  ///
  ///
  /// Typically a [Text] widget.
  final Widget? content;

  /// Style for the text in the [content] of this [CustomRichText].
  ///
  /// If null, defaults to [TextTheme.bodyMedium] of [ThemeData.textTheme].
  final TextStyle? contentTextStyle;

  ///
  ///
  /// If null, defaults to 1.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final defaults = Theme.of(context).textTheme.bodyMedium!;

    if (icon == null && content == null) {
      return DefaultTextStyle(
        style: labelTextStyle ?? defaults,
        softWrap: maxLines != 1,
        overflow: TextOverflow.fade,
        maxLines: maxLines,
        child: label,
      );
    }

    final fontSize = labelTextStyle?.fontSize ?? defaults.fontSize ?? 24.0;

    final softWrap = maxLines != 1 || content != null;

    final spans = <InlineSpan>[];

    /// Creates a widget span for the input icon, if defined.
    if (icon != null) {
      spans.add(
        TextSpan(
          children: <InlineSpan>[
            WidgetSpan(
              baseline: TextBaseline.ideographic,
              alignment: PlaceholderAlignment.middle,
              child: IconTheme(
                data: IconThemeData(
                  size: fontSize + 4.0,
                  color: iconColor ?? labelTextStyle?.color ?? defaults.color,
                  applyTextScaling: false,
                ),
                child: icon!,
              ),
            ),
            const WidgetSpan(child: SizedBox(width: 4.0)),
          ],
        ),
      );
    }

    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        baseline: TextBaseline.alphabetic,
        child: DefaultTextStyle(
          style: labelTextStyle ?? defaults,
          softWrap: softWrap,
          child: label,
        ),
      ),
    );

    /// Creates a text span specifically for the content, if defined.
    if (content != null) {
      spans.add(
        TextSpan(
          children: <InlineSpan>[
            WidgetSpan(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: 8.0),
                child: DefaultTextStyle(
                  style: contentTextStyle ?? defaults,
                  child: content!,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.start,
      softWrap: softWrap,
      overflow: TextOverflow.fade,
      textScaler: TextScaler.noScaling,
    );
  }
}
