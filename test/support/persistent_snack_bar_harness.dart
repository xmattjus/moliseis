import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

import 'mock_logger.dart';
import 'typography_measurement_harness.dart';

/// App shell for persistent Snackbar presentation and lifecycle tests.
final class PersistentSnackBarHarness {
  /// Creates a shell at the requested logical viewport and text scale.
  PersistentSnackBarHarness({
    Size size = const Size(400, 700),
    TextScaler textScaler = TextScaler.noScaling,
  }) : mediaQuery = ValueNotifier(
         MediaQueryData(size: size, textScaler: textScaler),
       );

  /// Mutable viewport and text inputs consumed by the test app.
  final ValueNotifier<MediaQueryData> mediaQuery;

  /// The mounted app context used to call the global Snackbar helpers.
  late BuildContext context;

  /// Builds the app with its requested semantic light or dark theme.
  Widget app({Brightness brightness = Brightness.light}) =>
      Provider<Logger>.value(
        value: MockLogger(),
        child: Builder(
          builder: (outerContext) => TypographyMeasurementApp(
            mediaQuery: mediaQuery,
            scaffoldMessengerKey: $scaffoldMessengerKey,
            theme: brightness == Brightness.light
                ? AppThemeData.light(context: outerContext)
                : AppThemeData.dark(context: outerContext),
            home: Builder(
              builder: (innerContext) {
                context = innerContext;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );

  /// Updates the logical viewport and accessible text scale.
  void setViewport({required Size size, required double textScale}) =>
      mediaQuery.value = MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      );

  /// Releases the mutable media query source.
  void dispose() => mediaQuery.dispose();
}
