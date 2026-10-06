import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';

/// Builds an actual application theme with test-only script coverage.
Widget typographyHarness({
  required Widget child,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  bool photoViewer = false,
  TextTheme? overrides,
}) => Builder(
  builder: (context) {
    final theme = photoViewer
        ? AppThemeData.photoViewer
        : brightness == Brightness.light
        ? AppThemeData.light(context: context)
        : AppThemeData.dark(context: context);
    return MaterialApp(
      theme: overrides == null
          ? theme
          : theme.copyWith(textTheme: theme.textTheme.merge(overrides)),
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('it'), Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: child,
    );
  },
);

/// Enumerates the public roles in their Material order.
List<TextStyle?> typographyRoles(TextTheme theme) => [
  theme.displayLarge,
  theme.displayMedium,
  theme.displaySmall,
  theme.headlineLarge,
  theme.headlineMedium,
  theme.headlineSmall,
  theme.titleLarge,
  theme.titleMedium,
  theme.titleSmall,
  theme.bodyLarge,
  theme.bodyMedium,
  theme.bodySmall,
  theme.labelLarge,
  theme.labelMedium,
  theme.labelSmall,
];
