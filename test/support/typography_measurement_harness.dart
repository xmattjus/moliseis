import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';

/// Loads the variable font for weight-sensitive width checks with app metrics.
Future<void> loadTypographyMeasurementFont() async {
  final loader = FontLoader('Lexend')
    ..addFont(rootBundle.load('assets/fonts/Lexend-VariableFont.ttf'));
  await loader.load();
}

/// Supplies mutable text inputs above the navigator and visible overlays.
class TypographyMeasurementApp extends StatelessWidget {
  /// Keeps [home] and overlay state mounted while [mediaQuery] changes.
  const TypographyMeasurementApp({
    required this.mediaQuery,
    required this.home,
    this.direction = TextDirection.ltr,
    this.locale = const Locale('en'),
    this.scaffoldMessengerKey,
    this.theme,
    super.key,
  });

  /// Text scaling, accessible styles and logical measurement viewport.
  final ValueListenable<MediaQueryData> mediaQuery;

  /// Surface being tested.
  final Widget home;

  /// Direction used for both measurement and rendering.
  final TextDirection direction;

  /// Locale inherited by rendered text and its measurement.
  final Locale locale;

  /// Optional messenger used by app-wide feedback.
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  /// Optional override for component-theme mismatch regression checks.
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: scaffoldMessengerKey,
    theme: theme ?? AppThemeData.light(context: context),
    builder: (context, child) => ValueListenableBuilder<MediaQueryData>(
      valueListenable: mediaQuery,
      builder: (context, data, _) => MediaQuery(
        data: data,
        child: Localizations.override(
          context: context,
          locale: locale,
          child: Directionality(textDirection: direction, child: child!),
        ),
      ),
    ),
    home: home,
  );
}

/// Measures the public effective paragraph already produced by [Text].
///
/// This reference consumes renderer inputs rather than recreating Text's
/// accessibility transformations in test code. The caller disposes the painter.
TextPainter measureRenderedText(
  RenderParagraph richText, {
  double maxWidth = double.infinity,
}) => TextPainter(
  text: richText.text,
  textDirection: richText.textDirection,
  textScaler: richText.textScaler,
  locale: richText.locale,
  maxLines: richText.maxLines,
)..layout(maxWidth: maxWidth);
