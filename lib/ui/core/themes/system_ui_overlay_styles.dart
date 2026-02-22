import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A utility class that provides theme-aware [SystemUiOverlayStyle] configurations
/// for different UI scenarios in the application.
///
/// NOTE: Setting the [SystemUiOverlayStyle] directly on the [AppBar] using its
/// `systemOverlayStyle` property while also having an `AnnotatedRegion` in the
/// widget tree may lead to unexpected behaviors.
///
/// Example usage with AnnotatedRegion:
/// ```dart
/// final overlayStyles = SystemUiOverlayStyles(context);
/// return AnnotatedRegion(value: overlayStyles.surface, child: ...);
/// ```
///
/// Example usage with AppBar:
/// ```dart
/// final overlayStyles = SystemUiOverlayStyles(context);
/// return Scaffold(appBar: AppBar(title: ..., systemOverlayStyle: overlayStyles.surface));
/// ```
class SystemUiOverlayStyles {
  /// The build context used to access the current theme.
  final BuildContext context;

  /// Creates a new [SystemUiOverlayStyles] instance.
  ///
  /// The [context] parameter is required to access the current theme
  /// and determine appropriate colors and brightness values.
  SystemUiOverlayStyles(this.context);

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

  SystemUiOverlayStyle get scaffoldShell {
    final theme = Theme.of(context);
    final navigationBarColor = theme.colorScheme.surfaceContainer;
    final statusBarColor = theme.colorScheme.surface;

    return theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            systemNavigationBarColor: navigationBarColor,
            systemNavigationBarDividerColor: navigationBarColor,
            systemNavigationBarIconBrightness: Brightness.light,
            statusBarColor: statusBarColor,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            systemNavigationBarColor: navigationBarColor,
            systemNavigationBarDividerColor: navigationBarColor,
            systemNavigationBarIconBrightness: Brightness.dark,
            statusBarColor: statusBarColor,
          );
  }

  SystemUiOverlayStyle get gallery {
    const color = Colors.transparent;

    return SystemUiOverlayStyle.light.copyWith(
      systemNavigationBarColor: color,
      systemNavigationBarDividerColor: color,
      statusBarColor: color,
    );
  }

  SystemUiOverlayStyle get post {
    final theme = Theme.of(context);
    const iconBrightness = Brightness.dark;
    final navigationBarColor = theme.colorScheme.surfaceContainer;
    const statusBarColor = Colors.transparent;

    return theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            systemNavigationBarColor: navigationBarColor,
            systemNavigationBarDividerColor: navigationBarColor,
            statusBarColor: statusBarColor,
            statusBarBrightness: iconBrightness,
            statusBarIconBrightness: iconBrightness,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            systemNavigationBarColor: navigationBarColor,
            systemNavigationBarDividerColor: navigationBarColor,
            statusBarColor: statusBarColor,
            statusBarBrightness: iconBrightness,
            statusBarIconBrightness: iconBrightness,
          );
  }
}
