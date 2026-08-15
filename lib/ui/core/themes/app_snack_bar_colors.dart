import 'package:flutter/material.dart';
import 'package:moliseis/ui/core/themes/app_colors_theme_extension.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';

/// The color set for a single [SnackBarType], used by
/// [AppColorsThemeExtension] to theme the app's custom snack bars.
///
/// Bundles the three colors a snack bar needs so each [SnackBarType] can be
/// carried as one value in the theme extension, lerped atomically during
/// theme transition, and swapped as a unit in
/// [AppColorsThemeExtension.copyWith] without callers needing to know about
/// individual channels.
///
/// Colors are derived in [AppColorsThemeExtension.light] and
/// [AppColorsThemeExtension.dark] from from HSL lightness steps chosen to
/// approximate M3 HCT tone roles that mirror the Material 3 `inverseSurface` /
/// `inversePrimary` / `onInverseSurface`
/// pairing, but applied to the app's light container backgrounds:
///
/// * [background] — the container fill (tone 90 light, tone 30 dark).
/// * [foreground] — the body text and leading icon color (tone 10 light,
///   tone 90 dark).
/// * [actionForeground] — the action label color (tone 40 light, tone 80
///   dark). An intermediate tone of the same seed palette as [background],
///   kept distinct from [foreground] so the action reads as a tinted text
///   button rather than body text.
final class AppSnackBarColors {
  /// Creates the per-type color set for a custom snack bar.
  ///
  /// All three colors are required; none has a default, because each
  /// [SnackBarType] derives its values from a different seed palette.
  const AppSnackBarColors({
    required this.background,
    required this.foreground,
    required this.actionForeground,
  });

  /// Interpolates between two [AppSnackBarColors] at time [t].
  ///
  /// Each channel is interpolated independently via [Color.lerp]. Because
  /// every channel is non-nullable, [Color.lerp] is guaranteed to return a
  /// non-null color, so the null-bang — unavoidable given [Color.lerp]'s
  /// nullable signature — is sound here.
  ///
  /// Used by [AppColorsThemeExtension.lerp] to animate between light and
  /// dark themes (or any two theme extensions) as a single unit rather than
  /// channel by channel.
  factory AppSnackBarColors.lerp(
    AppSnackBarColors x,
    AppSnackBarColors y,
    double t,
  ) => AppSnackBarColors(
    background: Color.lerp(x.background, y.background, t)!,
    foreground: Color.lerp(x.foreground, y.foreground, t)!,
    actionForeground: Color.lerp(x.actionForeground, y.actionForeground, t)!,
  );

  /// The snack bar's container fill color.
  ///
  /// Equivalent to a Material 3 `*Container` role (tone 90 in light, tone
  /// 30 in dark). Light enough to host dark [foreground] text.
  final Color background;

  /// The color for the leading icon and the body text.
  ///
  /// Equivalent to an M3 `on*Container` role (tone 10 - tone 30 in light,
  /// tone 90 in dark). Paired with [background] to meet a contrast ratio of at
  /// least 4.5:1.
  final Color foreground;

  /// The color for the [SnackBarAction] label.
  ///
  /// An intermediate tone of the same seed palette as [background] (tone 40
  /// in light, tone 80 in dark), mirroring how M3's `inversePrimary`
  /// relates to `inverseSurface`. Kept distinct from [foreground] so the
  /// action reads as a tinted text button — not body text.
  final Color actionForeground;
}
