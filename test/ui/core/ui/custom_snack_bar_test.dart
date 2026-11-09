import 'dart:async';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/ui/core/themes/app_colors_theme_extension.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

import '../../../support/mock_logger.dart';
import '../../../support/typography_measurement_harness.dart';

void main() {
  tearDown(clearAppSnackBars);

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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();

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

  testWidgets('persistent recovery resumes after ordinary queue settlement', (
    tester,
  ) async {
    late BuildContext context;
    var validations = 0;

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

    showPersistentSnackBar(
      context: context,
      textContent: 'Hai una modifica interrotta da recuperare.',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () async {
        validations++;
        return true;
      },
      onDismissed: () {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Riprendi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Riprendi'), findsOneWidget);

    showSnackBar(
      context: context,
      textContent: 'Ordinario A',
      duration: SnackBarDuration.extrashort,
    );
    showSnackBar(
      context: context,
      textContent: 'Ordinario B',
      duration: SnackBarDuration.extrashort,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ordinario A'), findsOneWidget);
    expect(find.text('Riprendi'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Ordinario B'), findsOneWidget);
    expect(validations, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Riprendi'), findsOneWidget);
    expect(validations, 2);
  });

  testWidgets('replacement suspends recovery but direct clear revokes it', (
    tester,
  ) async {
    late BuildContext context;
    var dismissed = false;
    var validations = 0;

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

    final cancel = showPersistentSnackBar(
      context: context,
      textContent: 'Hai una modifica interrotta da recuperare.',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () async {
        validations++;
        return true;
      },
      onDismissed: () => dismissed = true,
    );
    await tester.pumpAndSettle();

    showSnackBar(
      context: context,
      textContent: 'Sostituzione',
      duration: SnackBarDuration.extrashort,
      replaceCurrent: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Sostituzione'), findsOneWidget);
    expect(dismissed, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(validations, 2);
    expect(find.text('Riprendi'), findsOneWidget);

    clearAppSnackBars();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Riprendi'), findsNothing);
    expect(dismissed, isFalse);
    cancel();
    cancel();

    showSnackBar(
      context: context,
      textContent: 'Feedback pending',
      duration: SnackBarDuration.extrashort,
    );
    final cancelPending = showPersistentSnackBar(
      context: context,
      textContent: 'Hai una modifica interrotta da recuperare.',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () {},
    );
    cancelPending();
    await tester.pumpAndSettle();
    expect(find.text('Riprendi'), findsNothing);

    showSnackBar(
      context: context,
      textContent: 'Feedback to clear',
      duration: SnackBarDuration.extrashort,
    );
    showPersistentSnackBar(
      context: context,
      textContent: 'Hai una modifica interrotta da recuperare.',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () {},
    );
    clearAppSnackBars();
    await tester.pumpAndSettle();
    expect(find.text('Riprendi'), findsNothing);

    showSnackBar(
      context: context,
      textContent: 'Ordinary current',
      duration: SnackBarDuration.extrashort,
    );
    final validationsBeforePending = validations;
    showPersistentSnackBar(
      context: context,
      textContent: 'Hai una modifica interrotta da recuperare.',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () async {
        validations++;
        return true;
      },
      onDismissed: () {},
    );
    showSnackBar(
      context: context,
      textContent: 'Replacement for pending recovery',
      duration: SnackBarDuration.extrashort,
      replaceCurrent: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Replacement for pending recovery'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Riprendi'), findsOneWidget);
    expect(validations, validationsBeforePending + 1);
  });

  testWidgets('validation repeats after feedback arrives during validation', (
    tester,
  ) async {
    late BuildContext context;
    final firstValidation = Completer<bool>();
    var validations = 0;

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

    showPersistentSnackBar(
      context: context,
      textContent: 'Hai una modifica interrotta da recuperare.',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () {
        validations++;
        return validations == 1 ? firstValidation.future : Future.value(true);
      },
      onDismissed: () {},
    );
    showSnackBar(
      context: context,
      textContent: 'Feedback',
      duration: SnackBarDuration.extrashort,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    firstValidation.complete(true);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(validations, 2);
    expect(find.text('Riprendi'), findsOneWidget);
  });

  testWidgets('native close dismisses recovery and calls its owner once', (
    tester,
  ) async {
    late BuildContext context;
    var dismissals = 0;

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

    showPersistentSnackBar(
      context: context,
      textContent: 'Hai una modifica interrotta da recuperare.',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () => dismissals++,
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).showCloseIcon,
      isTrue,
    );
    final closeButton = find.byType(IconButton);
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();
    expect(dismissals, 1);
    expect(find.text('Riprendi'), findsNothing);
  });

  for (final isDark in [false, true]) {
    testWidgets(
      'persistent action and close stay accessible at narrow and wide widths '
      'with enlarged text (${isDark ? 'dark' : 'light'})',
      (tester) async {
        final media = ValueNotifier(
          const MediaQueryData(
            size: Size(320, 600),
            textScaler: TextScaler.linear(2),
          ),
        );
        addTearDown(media.dispose);
        late BuildContext context;

        await tester.pumpWidget(
          Provider<Logger>.value(
            value: MockLogger(),
            child: Builder(
              builder: (outerContext) => MaterialApp(
                scaffoldMessengerKey: $scaffoldMessengerKey,
                theme: isDark
                    ? AppThemeData.dark(context: outerContext)
                    : AppThemeData.light(context: outerContext),
                builder: (context, child) => ValueListenableBuilder(
                  valueListenable: media,
                  builder: (context, data, _) =>
                      MediaQuery(data: data, child: child!),
                ),
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

        showPersistentSnackBar(
          context: context,
          textContent: 'Hai una modifica interrotta da recuperare.',
          actionLabel: 'Riprendi',
          onActionPressed: () {},
          revalidate: () async => true,
          onDismissed: () {},
        );
        await tester.pumpAndSettle();

        for (final size in [const Size(320, 600), const Size(900, 600)]) {
          media.value = MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(2),
          );
          await tester.pump();
          expect(find.text('Riprendi'), findsOneWidget);
          final close = find.byType(IconButton);
          expect(close, findsOneWidget);
          expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
          expect(
            tester.getSize(find.byType(SnackBarAction)).height,
            greaterThanOrEqualTo(48),
          );
          expect(find.byTooltip('Close'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  group('ambient typography measurement', () {
    setUpAll(loadTypographyMeasurementFont);

    for (final direction in TextDirection.values) {
      testWidgets('visible feedback follows current inputs in $direction', (
        tester,
      ) async {
        final inputs = ValueNotifier(
          const MediaQueryData(size: Size(390, 600)),
        );
        addTearDown(inputs.dispose);
        late BuildContext context;
        const message = 'Aggiornamento pronto per tutti';
        await tester.pumpWidget(
          TypographyMeasurementApp(
            mediaQuery: inputs,
            direction: direction,
            scaffoldMessengerKey: $scaffoldMessengerKey,
            home: Builder(
              builder: (innerContext) {
                context = innerContext;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        );
        showSnackBar(
          context: context,
          textContent: message,
          duration: SnackBarDuration.long,
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        for (final data in [
          const MediaQueryData(size: Size(390, 600)),
          const MediaQueryData(
            size: Size(390, 600),
            textScaler: TextScaler.linear(2),
          ),
          const MediaQueryData(
            size: Size(390, 600),
            boldText: true,
            lineHeightScaleFactorOverride: 2,
            letterSpacingOverride: 6,
            wordSpacingOverride: 8,
          ),
          const MediaQueryData(size: Size(390, 600)),
        ]) {
          inputs.value = data;
          await tester.pump();
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text(message),
              matching: find.byType(RichText),
            ),
          );
          final reference = measureRenderedText(
            paragraph,
            maxWidth: data.size.width - 48,
          );
          final lineCount = reference.computeLineMetrics().length;
          reference.dispose();
          final stackedAction = find.ancestor(
            of: find.byType(SnackBarAction),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Align &&
                  widget.alignment == AlignmentGeometry.bottomEnd,
            ),
          );
          expect(stackedAction, lineCount > 1 ? findsOneWidget : findsNothing);
          expect(paragraph.textDirection, direction);
          expect(paragraph.locale, const Locale('en'));
          expect(paragraph.textScaler, data.textScaler);
          final style = paragraph.text.style!;
          if (data.boldText) {
            expect(style.fontWeight, FontWeight.bold);
          }
          if (data.lineHeightScaleFactorOverride != null) {
            expect(style.height, data.lineHeightScaleFactorOverride);
            expect(style.letterSpacing, data.letterSpacingOverride);
            expect(style.wordSpacing, data.wordSpacingOverride);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
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
          await tester.pump(const Duration(milliseconds: 100));

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
