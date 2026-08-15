import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/ui/core/themes/app_colors_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

import '../../../support/mock_logger.dart';

void main() {
  testWidgets('showSnackBar does not throw when providers are present', (
    tester,
  ) async {
    late BuildContext context;

    await tester.pumpWidget(
      Provider<Logger>.value(
        value: MockLogger(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      () => showSnackBar(context: context, textContent: 'Message'),
      returnsNormally,
    );
  });

  testWidgets('showSnackBar does not throw when providers are NOT present', (
    tester,
  ) async {
    late BuildContext context;

    await tester.pumpWidget(
      Provider<Logger?>.value(
        value: null,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(
      () => showSnackBar(context: context, textContent: 'Message'),
      returnsNormally,
    );
  });

  group('showSnackBar action color', () {
    for (final type in SnackBarType.values) {
      testWidgets(
        '$type action label resolves to the per-type actionForeground',
        (
          tester,
        ) async {
          late BuildContext context;
          late AppColorsThemeExtension appColors;

          await tester.pumpWidget(
            Provider<Logger>.value(
              value: MockLogger(),
              child: Builder(
                builder: (outerContext) => MaterialApp(
                  scaffoldMessengerKey: $scaffoldMessengerKey,
                  theme: AppThemeData.light(context: outerContext),
                  home: Builder(
                    builder: (innerContext) {
                      context = innerContext;
                      appColors = innerContext.appColors;
                      return const Scaffold(body: SizedBox.shrink());
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          showSnackBar(
            context: context,
            textContent: 'msg',
            type: type,
            action: SnackBarAction(label: 'Annulla', onPressed: () {}),
          );
          await tester.pumpAndSettle();

          final expected = switch (type) {
            SnackBarType.info => appColors.infoSnackBar.actionForeground,
            SnackBarType.warning => appColors.warningSnackBar.actionForeground,
            SnackBarType.error => appColors.errorSnackBar.actionForeground,
          };

          expect(find.text('Annulla'), findsOneWidget);
          final button = tester.widget<TextButton>(
            find.ancestor(
              of: find.text('Annulla'),
              matching: find.byType(TextButton),
            ),
          );
          final actual = button.style?.foregroundColor?.resolve({});

          expect(actual, isNotNull);
          expect(actual, equals(expected));
        },
      );
    }
  });
}
