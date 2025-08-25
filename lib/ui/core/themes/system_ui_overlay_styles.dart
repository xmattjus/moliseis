import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A utility class that provides theme-aware [SystemUiOverlayStyle] configurations
/// for different UI scenarios in the application.
///
/// This class automatically adapts the system UI overlay (status bar and navigation bar)
/// colors and icon brightness based on the current theme (light/dark mode).
///
/// Example usage:
/// ```dart
/// final overlayStyles = SystemUiOverlayStyles(context);
/// SystemChrome.setSystemUIOverlayStyle(overlayStyles.surface);
/// ```
class SystemUiOverlayStyles {
  /// The build context used to access the current theme.
  final BuildContext context;

  /// Creates a new [SystemUiOverlayStyles] instance.
  ///
  /// The [context] parameter is required to access the current theme
  /// and determine appropriate colors and brightness values.
  SystemUiOverlayStyles(this.context);

  /// Returns a [SystemUiOverlayStyle] that uses the surface color for both
  /// status bar and navigation bar.
  ///
  /// This style is suitable for screens where the content extends edge-to-edge
  /// and uses the surface color as the background. The icon brightness is
  /// automatically adjusted based on the current theme brightness to ensure
  /// proper contrast.
  SystemUiOverlayStyle get surface {
    final theme = Theme.of(context);
    final color = theme.colorScheme.surface;
    final iconBrightness = switch (theme.brightness) {
      Brightness.dark => Brightness.light,
      Brightness.light => Brightness.dark,
    };

    return SystemUiOverlayStyle(
      systemNavigationBarColor: color,
      systemNavigationBarDividerColor: color,
      systemNavigationBarIconBrightness: iconBrightness,
      statusBarColor: color,
      statusBarBrightness: iconBrightness,
      statusBarIconBrightness: iconBrightness,
    );
  }

  /// Returns a [SystemUiOverlayStyle] that uses surface color for the status bar
  /// and surface container color for the navigation bar.
  ///
  /// This style is ideal for screens with bottom navigation bars or similar
  /// UI elements that need to be visually separated from the main content area.
  /// The navigation bar uses a slightly different color (surfaceContainer) to
  /// provide visual hierarchy while maintaining theme consistency.
  SystemUiOverlayStyle get surfaceWithNavigationBar {
    final theme = Theme.of(context);
    final iconBrightness = switch (theme.brightness) {
      Brightness.dark => Brightness.light,
      Brightness.light => Brightness.dark,
    };
    final navigationBarColor = theme.colorScheme.surfaceContainer;
    final statusBarColor = theme.colorScheme.surface;

    return SystemUiOverlayStyle(
      systemNavigationBarColor: navigationBarColor,
      systemNavigationBarDividerColor: navigationBarColor,
      systemNavigationBarIconBrightness: iconBrightness,
      statusBarColor: statusBarColor,
      statusBarBrightness: iconBrightness,
      statusBarIconBrightness: iconBrightness,
    );
  }

  /// Returns a [SystemUiOverlayStyle] with transparent background and light icons
  /// for gallery or full-screen media viewing experiences.
  ///
  /// This style is designed for immersive content viewing where the system UI
  /// should be minimally intrusive. It uses transparent colors for both status bar
  /// and navigation bar, with light-colored icons that work well over dark or
  /// media content backgrounds. This is ideal for image galleries, video players,
  /// or any full-screen media presentation.
  SystemUiOverlayStyle get gallerySurface {
    const color = Colors.transparent;
    const iconBrightness = Brightness.light;

    return const SystemUiOverlayStyle(
      systemNavigationBarColor: color,
      systemNavigationBarDividerColor: color,
      systemNavigationBarIconBrightness: iconBrightness,
      statusBarColor: color,
      statusBarBrightness: iconBrightness,
      statusBarIconBrightness: iconBrightness,
    );
  }
}
