import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/custom_snack_bar.dart';
import 'package:moliseis/utils/extensions/build_context_extensions.dart';

import '../../../support/persistent_snack_bar_harness.dart';

void main() {
  tearDown(clearAppSnackBars);

  testWidgets(
    'persistent action outlives five seconds; ordinary action expires',
    (tester) async {
      final harness = PersistentSnackBarHarness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();

      showSnackBar(
        context: harness.context,
        textContent: 'Ordinario',
        duration: SnackBarDuration.long,
        action: SnackBarAction(label: 'Annulla', onPressed: () {}),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(find.text('Annulla'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Ordinario'), findsNothing);

      final cancel = showPersistentSnackBar(
        context: harness.context,
        textContent: 'Hai una modifica interrotta da recuperare.',
        actionLabel: 'Riprendi',
        onActionPressed: () {},
        revalidate: () async => true,
        onDismissed: () {},
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Riprendi'), findsOneWidget);
      expect(find.byType(SnackBarAction), findsOneWidget);
      cancel();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('persistent controls stay visible and accessible at supported '
        'widths in $brightness', (tester) async {
      final harness = PersistentSnackBarHarness();
      addTearDown(harness.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(harness.app(brightness: brightness));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();

      showPersistentSnackBar(
        context: harness.context,
        textContent: 'Una modifica interrotta da recuperare nel modulo.',
        actionLabel: 'Riprendi',
        onActionPressed: () {},
        revalidate: () async => true,
        onDismissed: () {},
      );
      await tester.pumpAndSettle();

      for (final (size, scale) in [
        (const Size(320, 640), 1.0),
        (const Size(320, 640), 2.0),
        (const Size(900, 900), 1.0),
        (const Size(900, 900), 2.0),
      ]) {
        await tester.binding.setSurfaceSize(size);
        harness.setViewport(size: size, textScale: scale);
        await tester.pump();
        expect(find.text('Riprendi'), findsOneWidget);
        expect(find.byType(SnackBarAction), findsOneWidget);

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        final infoColors = harness.context.appColors.infoSnackBar;
        expect(snackBar.showCloseIcon, isTrue);
        expect(snackBar.persist, isTrue);
        expect(snackBar.backgroundColor, infoColors.background);
        expect(snackBar.closeIconColor, infoColors.foreground);
        expect(
          tester.widget<SnackBarAction>(find.byType(SnackBarAction)).textColor,
          infoColors.actionForeground,
        );

        final close = find.byType(IconButton);
        expect(close, findsOneWidget);
        final closeButton = tester.widget<IconButton>(close);
        expect(
          closeButton.tooltip,
          MaterialLocalizations.of(harness.context).closeButtonTooltip,
        );
        expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
        expect(tester.getSemantics(close).tooltip, closeButton.tooltip);
        expect(tester.takeException(), isNull);
      }
      semantics.dispose();
    });
  }

  testWidgets('canceling visible recovery preserves ordinary queue order', (
    tester,
  ) async {
    final harness = PersistentSnackBarHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    var dismissals = 0;
    final cancel = showPersistentSnackBar(
      context: harness.context,
      textContent: 'Recovery',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () => dismissals++,
    );
    await tester.pumpAndSettle();
    expect(find.text('Recovery'), findsOneWidget);

    showSnackBar(
      context: harness.context,
      textContent: 'Feedback A',
      duration: SnackBarDuration.extrashort,
    );
    showSnackBar(
      context: harness.context,
      textContent: 'Feedback B',
      duration: SnackBarDuration.extrashort,
    );
    cancel();
    cancel();
    await tester.pumpAndSettle();
    expect(find.text('Feedback A'), findsOneWidget);
    expect(find.text('Recovery'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Feedback B'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Feedback A'), findsNothing);
    expect(find.text('Feedback B'), findsNothing);
    expect(dismissals, 0);
  });

  testWidgets('native downward swipe dismisses persistent recovery', (
    tester,
  ) async {
    final harness = PersistentSnackBarHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    var dismissals = 0;
    showPersistentSnackBar(
      context: harness.context,
      textContent: 'Recovery',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () => dismissals++,
    );
    await tester.pumpAndSettle();
    expect(find.text('Recovery'), findsOneWidget);

    await tester.drag(find.byType(SnackBar), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('Recovery'), findsNothing);
    expect(dismissals, 1);
  });

  testWidgets('canceling pending recovery does not close ordinary entries', (
    tester,
  ) async {
    final harness = PersistentSnackBarHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    showSnackBar(
      context: harness.context,
      textContent: 'Feedback A',
      duration: SnackBarDuration.extrashort,
    );
    showSnackBar(
      context: harness.context,
      textContent: 'Feedback B',
      duration: SnackBarDuration.extrashort,
    );
    final cancel = showPersistentSnackBar(
      context: harness.context,
      textContent: 'Recovery',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () {},
    );
    cancel();
    await tester.pumpAndSettle();
    expect(find.text('Feedback A'), findsOneWidget);
    expect(find.text('Feedback B'), findsNothing);
    expect(find.text('Recovery'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Feedback B'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Feedback B'), findsNothing);
  });

  testWidgets(
    'replaceCurrent replaces pending ordinary tail, then revalidates recovery',
    (tester) async {
      final harness = PersistentSnackBarHarness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      var validations = 0;
      showSnackBar(
        context: harness.context,
        textContent: 'Old A',
        duration: SnackBarDuration.long,
      );
      showSnackBar(
        context: harness.context,
        textContent: 'Old B',
        duration: SnackBarDuration.long,
      );
      showPersistentSnackBar(
        context: harness.context,
        textContent: 'Recovery',
        actionLabel: 'Riprendi',
        onActionPressed: () {},
        revalidate: () async {
          validations++;
          return true;
        },
        onDismissed: () {},
      );
      showSnackBar(
        context: harness.context,
        textContent: 'Replacement',
        duration: SnackBarDuration.extrashort,
        replaceCurrent: true,
      );
      showSnackBar(
        context: harness.context,
        textContent: 'Later ordinary',
        duration: SnackBarDuration.extrashort,
      );
      await tester.pumpAndSettle();
      expect(find.text('Replacement'), findsOneWidget);
      expect(find.text('Old A'), findsNothing);
      expect(find.text('Old B'), findsNothing);
      expect(find.text('Recovery'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Later ordinary'), findsOneWidget);
      expect(find.text('Recovery'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Later ordinary'), findsNothing);
      expect(find.text('Recovery'), findsOneWidget);
      expect(validations, greaterThanOrEqualTo(1));
    },
  );

  testWidgets('feedback arriving during validation revokes its stale result', (
    tester,
  ) async {
    final harness = PersistentSnackBarHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final validationStarted = Completer<void>();
    final firstValidation = Completer<bool>();
    var validations = 0;
    showSnackBar(
      context: harness.context,
      textContent: 'Feedback A',
      duration: SnackBarDuration.extrashort,
    );
    showPersistentSnackBar(
      context: harness.context,
      textContent: 'Recovery',
      actionLabel: 'Riprendi',
      onActionPressed: () {},
      revalidate: () {
        validations++;
        if (validations == 1) {
          validationStarted.complete();
          return firstValidation.future;
        }
        return Future<bool>.value(true);
      },
      onDismissed: () {},
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(validationStarted.isCompleted, isTrue);
    expect(find.text('Recovery'), findsNothing);

    showSnackBar(
      context: harness.context,
      textContent: 'Feedback B',
      duration: SnackBarDuration.extrashort,
    );
    await tester.pumpAndSettle();
    firstValidation.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Feedback B'), findsOneWidget);
    expect(find.text('Recovery'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Recovery'), findsOneWidget);
    expect(validations, 2);
  });

  testWidgets('new candidate replaces active recovery without stale close', (
    tester,
  ) async {
    final harness = PersistentSnackBarHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    var oldDismissals = 0;
    final cancelOld = showPersistentSnackBar(
      context: harness.context,
      textContent: 'Candidate A',
      actionLabel: 'Riprendi A',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () => oldDismissals++,
    );
    await tester.pumpAndSettle();
    expect(find.text('Candidate A'), findsOneWidget);

    final cancelNew = showPersistentSnackBar(
      context: harness.context,
      textContent: 'Candidate B',
      actionLabel: 'Riprendi B',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () {},
    );
    await tester.pumpAndSettle();
    cancelOld();
    await tester.pumpAndSettle();
    expect(find.text('Candidate A'), findsNothing);
    expect(find.text('Candidate B'), findsOneWidget);
    expect(find.text('Riprendi B'), findsOneWidget);
    expect(oldDismissals, 0);
    cancelNew();
  });

  testWidgets('new candidate replaces pending recovery behind ordinary tail', (
    tester,
  ) async {
    final harness = PersistentSnackBarHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    showSnackBar(
      context: harness.context,
      textContent: 'Ordinary tail',
      duration: SnackBarDuration.extrashort,
    );
    var oldValidations = 0;
    var newValidations = 0;
    final cancelOld = showPersistentSnackBar(
      context: harness.context,
      textContent: 'Candidate A',
      actionLabel: 'Riprendi A',
      onActionPressed: () {},
      revalidate: () async {
        oldValidations++;
        return true;
      },
      onDismissed: () {},
    );
    final cancelNew = showPersistentSnackBar(
      context: harness.context,
      textContent: 'Candidate B',
      actionLabel: 'Riprendi B',
      onActionPressed: () {},
      revalidate: () async {
        newValidations++;
        return true;
      },
      onDismissed: () {},
    );

    await tester.pumpAndSettle();
    expect(find.text('Ordinary tail'), findsOneWidget);
    expect(find.text('Candidate A'), findsNothing);
    expect(find.text('Candidate B'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Candidate A'), findsNothing);
    expect(find.text('Candidate B'), findsOneWidget);
    expect(find.text('Riprendi B'), findsOneWidget);
    expect(oldValidations, 0);
    expect(newValidations, 1);
    cancelOld();
    await tester.pumpAndSettle();
    expect(find.text('Candidate B'), findsOneWidget);
    cancelNew();
  });

  testWidgets('revoked recovery cannot return after pending validation', (
    tester,
  ) async {
    final harness = PersistentSnackBarHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    final validationStarted = Completer<void>();
    final staleValidation = Completer<bool>();
    var dismissals = 0;
    showSnackBar(
      context: harness.context,
      textContent: 'Ordinary feedback',
      duration: SnackBarDuration.extrashort,
    );
    final cancelOld = showPersistentSnackBar(
      context: harness.context,
      textContent: 'Old recovery',
      actionLabel: 'Old action',
      onActionPressed: () {},
      revalidate: () {
        validationStarted.complete();
        return staleValidation.future;
      },
      onDismissed: () => dismissals++,
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(validationStarted.isCompleted, isTrue);

    cancelOld();
    final cancelNew = showPersistentSnackBar(
      context: harness.context,
      textContent: 'New recovery',
      actionLabel: 'New action',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () {},
    );
    staleValidation.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Old recovery'), findsNothing);
    expect(find.text('New recovery'), findsOneWidget);
    expect(find.text('New action'), findsOneWidget);
    expect(dismissals, 0);
    cancelNew();
  });

  testWidgets('messenger replacement abandons old tail and recovery owner', (
    tester,
  ) async {
    final harness = PersistentSnackBarHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    showSnackBar(
      context: harness.context,
      textContent: 'Old messenger tail',
      duration: SnackBarDuration.long,
    );
    var oldDismissals = 0;
    showPersistentSnackBar(
      context: harness.context,
      textContent: 'Old recovery',
      actionLabel: 'Old action',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () => oldDismissals++,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Old messenger tail'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    showPersistentSnackBar(
      context: harness.context,
      textContent: 'New recovery',
      actionLabel: 'New action',
      onActionPressed: () {},
      revalidate: () async => true,
      onDismissed: () {},
    );
    await tester.pumpAndSettle();
    expect(find.text('Old recovery'), findsNothing);
    expect(find.text('New recovery'), findsOneWidget);
    expect(find.text('New action'), findsOneWidget);
    expect(oldDismissals, 0);
  });

  testWidgets(
    'global clear revokes pending recovery and discarded ordinary tails',
    (tester) async {
      final harness = PersistentSnackBarHarness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      for (final text in ['Ordinary A', 'Ordinary B']) {
        showSnackBar(
          context: harness.context,
          textContent: text,
          duration: SnackBarDuration.long,
        );
      }
      var oldValidations = 0;
      final cancelOld = showPersistentSnackBar(
        context: harness.context,
        textContent: 'Old recovery',
        actionLabel: 'Old action',
        onActionPressed: () {},
        onDismissed: () {},
        revalidate: () async {
          oldValidations++;
          return true;
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('Ordinary A'), findsOneWidget);
      expect(oldValidations, 0);
      clearAppSnackBars();
      await tester.pumpAndSettle();
      expect(find.text('Ordinary A'), findsNothing);
      expect(find.text('Ordinary B'), findsNothing);
      showPersistentSnackBar(
        context: harness.context,
        textContent: 'Fresh recovery',
        actionLabel: 'Fresh action',
        onActionPressed: () {},
        onDismissed: () {},
        revalidate: () async => true,
      );
      await tester.pumpAndSettle();
      cancelOld();
      cancelOld();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Old recovery'), findsNothing);
      expect(find.text('Fresh recovery'), findsOneWidget);
      expect(oldValidations, 0);
    },
  );
}
