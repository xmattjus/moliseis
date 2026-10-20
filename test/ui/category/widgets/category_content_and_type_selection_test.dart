import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/content_type.dart';
import 'package:moliseis/ui/category/widgets/category_content_and_type_selection.dart';

import '../../../support/category_selection_test_support.dart';

void main() {
  for (final width in [400.0, 1000.0]) {
    for (final category in [false, true]) {
      final field = category ? 'category' : 'type';
      final surface = width == 400 ? 'sheet' : 'dialog';
      final initialKey = category
          ? const ValueKey(ContentCategory.nature)
          : const ValueKey(ContentType.event);
      final otherKey = category
          ? const ValueKey(ContentCategory.history)
          : const ValueKey(ContentType.place);
      final all = category
          ? ContentCategory.values
                .where((value) => value != ContentCategory.unknown)
                .toSet()
          : ContentType.values.toSet();
      final initial = category ? {ContentCategory.nature} : {ContentType.event};
      final other = category ? {ContentCategory.history} : {ContentType.place};

      testWidgets(
        '$field empty draft survives rebuild and resets on $surface close',
        (tester) async {
          final harness = CategorySelectionTestHarness();
          await harness.pump(tester, width);
          await harness.open(tester, category: category);
          expect(
            find.byType(AlertDialog),
            width == 400 ? findsNothing : findsOneWidget,
          );
          expect(
            find.byType(BottomSheet),
            width == 400 ? findsOneWidget : findsNothing,
          );
          await tester.tap(find.byKey(initialKey));
          await tester.pump();
          harness.rebuild();
          await tester.pump();
          expect(
            find.text(category ? 'Nessuna categoria' : 'Nessun tipo'),
            findsOneWidget,
          );
          expect(
            tester.widget<Checkbox>(find.byKey(initialKey)).value,
            isFalse,
          );
          expect(harness.calls, isEmpty);
          expect(tester.takeException(), isNull);
          await harness.close(tester, width);
          expect(harness.calls, [all]);
        },
      );

      testWidgets('$field empty draft continues editing across '
          'equal $surface rebuilds', (tester) async {
        final harness = CategorySelectionTestHarness();
        await harness.pump(tester, width);
        final state = tester.state(
          find.byType(CategoryContentAndTypeSelection),
        );
        await harness.open(tester, category: category);
        await tester.tap(find.byKey(initialKey));
        harness.rebuild();
        await tester.pump();
        await tester.tap(find.byKey(otherKey));
        harness.rebuild();
        await tester.pump();
        expect(
          tester.state(find.byType(CategoryContentAndTypeSelection)),
          same(state),
        );
        expect(harness.calls, isEmpty);
        await harness.close(tester, width);
        expect(harness.calls, [other]);
        expect(harness.categories, {ContentCategory.nature});
        expect(harness.types, {ContentType.event});
      });

      testWidgets(
        '$field changed confirmed field retires captured $surface draft',
        (tester) async {
          final harness = CategorySelectionTestHarness();
          await harness.pump(tester, width);
          await harness.open(tester, category: category);
          await tester.tap(find.byKey(initialKey));
          if (category) {
            harness.categories = {ContentCategory.history};
          } else {
            harness.types = {ContentType.place};
          }
          harness.rebuild();
          await tester.pump();
          expect(harness.calls, isEmpty);
          // The materialized old rows still edit their old draft only.
          await tester.tap(find.byKey(initialKey));
          await tester.pump();
          await harness.close(tester, width);
          expect(harness.calls, isEmpty);
          await harness.open(tester, category: category);
          expect(
            tester.widget<Checkbox>(find.byKey(initialKey)).value,
            isFalse,
          );
          expect(tester.widget<Checkbox>(find.byKey(otherKey)).value, isTrue);
          await harness.close(tester, width);
          expect(harness.calls, [other]);
        },
      );

      for (final observed in [false, true]) {
        testWidgets('$field A to B to A ${observed ? 'observed' : 'coalesced'} '
            'during $surface', (tester) async {
          final harness = CategorySelectionTestHarness();
          await harness.pump(tester, width);
          await harness.open(tester, category: category);
          await tester.tap(find.byKey(initialKey));
          if (category) {
            harness.categories = {ContentCategory.history};
          } else {
            harness.types = {ContentType.place};
          }
          harness.rebuild();
          if (observed) await tester.pump();
          if (category) {
            harness.categories = {ContentCategory.nature};
          } else {
            harness.types = {ContentType.event};
          }
          harness.rebuild();
          await tester.pump();
          await harness.close(tester, width);
          expect(harness.calls, observed ? isEmpty : [all]);
          if (observed) {
            await harness.open(tester, category: category);
            expect(
              tester.widget<Checkbox>(find.byKey(initialKey)).value,
              isTrue,
            );
            expect(
              tester.widget<Checkbox>(find.byKey(otherKey)).value,
              isFalse,
            );
            await harness.close(tester, width);
            expect(harness.calls, [initial]);
          }
        });
      }

      testWidgets(
        '$field draft survives other confirmed field change in $surface',
        (tester) async {
          final harness = CategorySelectionTestHarness();
          await harness.pump(tester, width);
          await harness.open(tester, category: category);
          await tester.tap(find.byKey(initialKey));
          await tester.tap(find.byKey(otherKey));
          if (category) {
            harness.types = {ContentType.place};
          } else {
            harness.categories = {ContentCategory.history};
          }
          harness.rebuild();
          await tester.pump();
          expect(find.text(category ? 'Luoghi' : 'Storia'), findsOneWidget);
          expect(harness.calls, isEmpty);
          await harness.close(tester, width);
          expect(harness.calls, [other]);
        },
      );

      for (final empty in [false, true]) {
        for (final replacement in [false, true]) {
          testWidgets('$field ${empty ? 'empty' : 'nonempty'} $surface draft '
              'cannot publish after '
              '${replacement ? 'owner replacement' : 'unmount'}', (
            tester,
          ) async {
            final harness = CategorySelectionTestHarness();
            await harness.pump(tester, width);
            final oldCalls = harness.calls;
            await harness.open(tester, category: category);
            if (empty) await tester.tap(find.byKey(initialKey));
            if (replacement) {
              harness.replaceOwner();
            } else {
              harness
                ..visible = false
                ..rebuild();
            }
            await tester.pump();
            await harness.close(tester, width);
            expect(oldCalls, isEmpty);
            expect(harness.calls, isEmpty);
            expect(tester.takeException(), isNull);
            if (replacement) {
              await harness.open(tester, category: category);
              expect(
                tester.widget<Checkbox>(find.byKey(initialKey)).value,
                isTrue,
              );
              await harness.close(tester, width);
              expect(harness.calls, [initial]);
            }
          });
        }
      }
    }
  }

  testWidgets(
    'different iteration order of equal confirmed sets preserves drafts',
    (tester) async {
      final harness = CategorySelectionTestHarness(
        types: {ContentType.event, ContentType.place},
      );
      await harness.pump(tester, 1000);
      await harness.open(tester, category: false);
      await tester.tap(find.byKey(const ValueKey(ContentType.event)));
      harness
        ..types = {ContentType.place, ContentType.event}
        ..rebuild();
      await tester.pump();
      await harness.close(tester, 1000);
      expect(harness.calls, [
        {ContentType.place},
      ]);
    },
  );
}
