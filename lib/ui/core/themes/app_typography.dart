import 'package:material_ui/material_ui.dart';

/// Semantic styles and emphasis derived from the current localized theme.
///
/// Standard baseline roles remain available through the theme's text theme.
class AppTypography {
  const AppTypography._(this._theme);

  /// Resolves the Material theme, including its script-specific geometry.
  factory AppTypography.of(BuildContext context) =>
      AppTypography._(Theme.of(context));

  final ThemeData _theme;

  /// The complete emphasized scale, derived only when requested.
  TextTheme get emphasized => _emphasized(_theme.textTheme);

  /// Section heading with the current scheme's primary color.
  TextStyle? get section =>
      _theme.textTheme.titleMedium?.copyWith(color: _theme.colorScheme.primary);

  /// Underlined supporting link with the current scheme's secondary color.
  TextStyle? get link {
    final color = _theme.colorScheme.secondary.withValues(alpha: 0.7);
    return _theme.textTheme.bodySmall?.copyWith(
      color: color,
      decoration: TextDecoration.underline,
      decorationColor: color,
    );
  }
}

// Temporary adapter until native emphasized roles preserve localized geometry
// and app families. Pinned AndroidX v0_103 implementation (2026-08-05):
// https://github.com/androidx/androidx/blob/160825094a81825468a95b115bfb1b541e549856/compose/material3/material3/src/commonMain/kotlin/androidx/compose/material3/tokens/TypeScaleTokens.kt
TextTheme _emphasized(TextTheme baseline) => baseline.copyWith(
  displayLarge: baseline.displayLarge?.copyWith(
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  ),
  displayMedium: baseline.displayMedium?.copyWith(fontWeight: FontWeight.w500),
  displaySmall: baseline.displaySmall?.copyWith(fontWeight: FontWeight.w500),
  headlineLarge: baseline.headlineLarge?.copyWith(fontWeight: FontWeight.w500),
  headlineMedium: baseline.headlineMedium?.copyWith(
    fontWeight: FontWeight.w500,
  ),
  headlineSmall: baseline.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
  titleLarge: baseline.titleLarge?.copyWith(fontWeight: FontWeight.w500),
  titleMedium: baseline.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  titleSmall: baseline.titleSmall?.copyWith(fontWeight: FontWeight.w700),
  bodyLarge: baseline.bodyLarge?.copyWith(
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
  ),
  bodyMedium: baseline.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
  bodySmall: baseline.bodySmall?.copyWith(fontWeight: FontWeight.w500),
  labelLarge: baseline.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  labelMedium: baseline.labelMedium?.copyWith(fontWeight: FontWeight.w700),
  labelSmall: baseline.labelSmall?.copyWith(fontWeight: FontWeight.w700),
);
