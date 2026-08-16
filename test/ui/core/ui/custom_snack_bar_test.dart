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
  testWidgets('logs a no-op when the global messenger is absent', (
    tester,
  ) async {
    final logger = MockLogger();
    late BuildContext context;

    await tester.pumpWidget(
      Provider<Logger>.value(
        value: logger,
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

    showSnackBar(context: context, textContent: 'Message');

    expect(logger.eventsOfType<SnackBarShowFailed>(), hasLength(1));
  });

  testWidgets('showSnackBar action invokes its callback', (tester) async {
    late BuildContext context;
    var actionPressed = false;

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
      textContent: 'Message',
      action: SnackBarAction(
        label: 'Annulla',
        onPressed: () => actionPressed = true,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Annulla'));

    expect(actionPressed, isTrue);
  });

  testWidgets('queues feedback by default', (tester) async {
    late BuildContext context;

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
      textContent: 'First',
      duration: SnackBarDuration.long,
    );
    showSnackBar(
      context: context,
      textContent: 'Queued',
      duration: SnackBarDuration.long,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Queued'), findsNothing);
  });

  testWidgets('replacement removes current and queued feedback', (
    tester,
  ) async {
    late BuildContext context;

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
      textContent: 'First',
      duration: SnackBarDuration.long,
    );
    showSnackBar(
      context: context,
      textContent: 'Queued',
      duration: SnackBarDuration.long,
    );
    await tester.pump(const Duration(milliseconds: 250));

    showSnackBar(
      context: context,
      textContent: 'Replacement',
      replaceCurrent: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('First'), findsNothing);
    expect(find.text('Queued'), findsNothing);
    expect(find.text('Replacement'), findsOneWidget);
  });

  group('showSnackBar action color', () {
    for (final type in SnackBarType.values) {
      testWidgets(
        '$type action label resolves to the per-type actionForeground',
        (tester) async {
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
            textContent: 'Message',
            type: type,
            action: SnackBarAction(label: 'Annulla', onPressed: () {}),
          );
          await tester.pumpAndSettle();

          final expected = switch (type) {
            SnackBarType.info => appColors.infoSnackBar.actionForeground,
            SnackBarType.warning => appColors.warningSnackBar.actionForeground,
            SnackBarType.error => appColors.errorSnackBar.actionForeground,
          };
          final button = tester.widget<TextButton>(
            find.ancestor(
              of: find.text('Annulla'),
              matching: find.byType(TextButton),
            ),
          );

          expect(find.text('Annulla'), findsOneWidget);
          expect(button.style?.foregroundColor?.resolve({}), equals(expected));
        },
      );
    }
  });
}
