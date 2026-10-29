import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/core/ui/unsaved_changes_dialog.dart';

import '../../../support/typography_harness.dart';
import '../../../support/typography_measurement_harness.dart';

void main() {
  const copy =
      'Salva ed esci conserva i campi nella bozza locale sul dispositivo, '
      'senza salvare il contributo sul server. Le foto preparate e la bozza '
      'precedente vengono conservate.';
  const sizes = [
    Size(320, 800),
    Size(390, 844),
    Size(700, 900),
    Size(1000, 900),
    Size(1300, 900),
    Size(1700, 1000),
    Size(700, 320),
  ];
  for (final size in sizes) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$size $brightness text scale $scale remains reachable', (
          tester,
        ) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final media = ValueNotifier(
            MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
          );
          addTearDown(media.dispose);
          UnsavedChangesDecision? result;
          await tester.pumpWidget(
            Builder(
              builder: (context) => TypographyMeasurementApp(
                mediaQuery: media,
                theme: brightness == Brightness.light
                    ? AppThemeData.light(context: context)
                    : AppThemeData.dark(context: context),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        result = await showDialog<UnsavedChangesDecision>(
                          context: context,
                          builder: (_) =>
                              const UnsavedChangesDialog(supportingText: copy),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final surface = tester.getSize(find.byType(Dialog));
          expect(surface.width, lessThanOrEqualTo(size.width));
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byType(UnsavedChangesDialog)),
            ).scale(10),
            scale * 10,
          );
          for (final text in [
            'Salvare le modifiche?',
            copy,
            'Annulla',
            'Esci senza salvare',
            'Salva ed esci',
          ]) {
            await tester.ensureVisible(find.text(text));
            await tester.pumpAndSettle();
            expect(find.text(text).hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.text('Salva ed esci'));
          await tester.pumpAndSettle();
          expect(result, UnsavedChangesDecision.saveAndExit);
          expect(find.text('Open'), findsOneWidget);
        });
      }
    }
  }

  for (final decision in UnsavedChangesDecision.values) {
    testWidgets('returns typed $decision and exposes button semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      UnsavedChangesDecision? result;
      await tester.pumpWidget(
        typographyHarness(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<UnsavedChangesDecision>(
                    context: context,
                    builder: (_) => const UnsavedChangesDialog(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final label = switch (decision) {
        UnsavedChangesDecision.saveAndExit => 'Salva ed esci',
        UnsavedChangesDecision.discardAndExit => 'Esci senza salvare',
        UnsavedChangesDecision.cancel => 'Annulla',
      };
      expect(
        tester.getSemantics(find.text(label)),
        matchesSemantics(
          label: label,
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          isFocused: decision == UnsavedChangesDecision.cancel,
        ),
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(result, decision);
      expect(find.text('Open'), findsOneWidget);
      semantics.dispose();
    });
  }

  for (final dismissal in ['Escape', 'Back', 'barrier']) {
    testWidgets('$dismissal dismisses only the modal without affirmation', (
      tester,
    ) async {
      var completed = false;
      UnsavedChangesDecision? result;
      await tester.pumpWidget(
        typographyHarness(
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<UnsavedChangesDecision>(
                    context: context,
                    builder: (_) => const UnsavedChangesDialog(),
                  );
                  completed = true;
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      switch (dismissal) {
        case 'Escape':
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        case 'Back':
          await tester.binding.handlePopRoute();
        case 'barrier':
          await tester.tapAt(const Offset(2, 2));
      }
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
      expect(find.byType(UnsavedChangesDialog), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  }

  testWidgets('Cancel initial focus and modal forward/reverse keyboard loop', (
    tester,
  ) async {
    UnsavedChangesDecision? result;
    await tester.pumpWidget(
      typographyHarness(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<UnsavedChangesDecision>(
                  context: context,
                  builder: (_) => const UnsavedChangesDialog(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, UnsavedChangesDecision.cancel);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, UnsavedChangesDecision.discardAndExit);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(result, UnsavedChangesDecision.saveAndExit);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, UnsavedChangesDecision.cancel);
    expect(tester.takeException(), isNull);
  });
}
