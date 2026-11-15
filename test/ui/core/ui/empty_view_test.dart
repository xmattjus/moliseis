import 'dart:ui' show SemanticsAction;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/content/nearby_content_horizontal_list.dart';
import 'package:moliseis/ui/core/ui/empty_view.dart';

import '../../../support/empty_view_geometry.dart';

void main() {
  testWidgets(
    'spacious icon text action rectangles match original composition',
    (tester) async {
      final reference = <Rect>[];
      for (final original in [true, false]) {
        const icon = Icon(Symbols.cancel, key: ValueKey('icon'));
        const text = Text(
          'Uno stato con testo arbitrario',
          key: ValueKey('text'),
        );
        final action = TextButton(
          key: const ValueKey('action'),
          onPressed: () {},
          child: const Text('Riprova'),
        );
        await tester.pumpWidget(
          emptyViewGeometryHarness(
            width: 500,
            height: 500,
            scale: 2,
            child: original
                ? OriginalEmptyViewGeometry(
                    icon: icon,
                    text: text,
                    action: action,
                  )
                : EmptyView(icon: icon, text: text, action: action),
          ),
        );
        final actual = [
          'icon',
          'text',
          'action',
        ].map((key) => tester.getRect(find.byKey(ValueKey(key)))).toList();
        if (original) {
          reference.addAll(actual);
        } else {
          expect(actual, reference);
          final column = tester.widget<Column>(
            find.descendant(
              of: find.byType(EmptyView),
              matching: find.byType(Column),
            ),
          );
          expect(column.children.map((child) => child.runtimeType), [
            Padding,
            DefaultTextStyle,
            TextButton,
          ]);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'real Nearby 320x216 scale2 retry scrolls and activates accessibly',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final state = ValueNotifier<NearbyContentPresentation>((
        pending: false,
        items: const [],
        error: StateError('failure'),
      ));
      addTearDown(state.dispose);
      var retries = 0;
      await tester.pumpWidget(
        emptyViewGeometryHarness(
          // The real component adds its title above its fixed 216px image row.
          height: 500,
          scale: 2,
          child: NearbyContentHorizontalList(
            loadListenable: state,
            loadKey: 'nearby',
            onLoad: () {},
            readState: () => state.value,
            onPressed: (_) {},
            onRetry: () => retries++,
          ),
        ),
      );
      final empty = find.byType(EmptyView);
      expect(tester.getSize(empty), const Size(320, 216));
      final scrollable = find.descendant(
        of: empty,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      final button = find.widgetWithText(TextButton, 'Riprova');
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      final target = tester.getRect(button);
      final viewport = tester.getRect(scrollable);
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      expect(viewport.intersect(target), target);
      expect(button.hitTestable(), findsOneWidget);
      await tester.tap(button);
      expect(retries, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(retries, 2);

      final node = tester.getSemantics(button);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.getSemanticsData().label, 'Riprova');
      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pump();
      expect(retries, 3);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  for (final intrinsic in [false, true]) {
    testWidgets(
      'sliver host intrinsic=$intrinsic keeps content and action usable',
      (tester) async {
        var calls = 0;
        final primary = ScrollController();
        addTearDown(primary.dispose);
        final state = EmptyView.error(
          text: const Text('Si è verificato un errore durante il caricamento.'),
          action: TextButton(
            onPressed: () => calls++,
            child: const Text('Riprova'),
          ),
        );
        await tester.pumpWidget(
          emptyViewGeometryHarness(
            scale: 2,
            child: PrimaryScrollController(
              controller: primary,
              child: CustomScrollView(
                primary: true,
                slivers: [
                  if (intrinsic)
                    SliverFillRemaining(hasScrollBody: false, child: state)
                  else
                    SliverToBoxAdapter(child: state),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final innerScroll = find.descendant(
          of: find.byType(EmptyView),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(innerScroll).position;
        expect(position.viewportDimension.isFinite, isTrue);
        expect(position.viewportDimension, greaterThan(0));
        expect(position.maxScrollExtent, 0);
        expect(primary.positions, hasLength(1));
        final button = find.widgetWithText(TextButton, 'Riprova');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(button.hitTestable(), findsOneWidget);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        await tester.tap(button);
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'viewport below action height preserves usable reachable target',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        emptyViewGeometryHarness(
          height: 40,
          child: EmptyView(
            text: const Text('Contenuto'),
            action: TextButton(
              onPressed: () => calls++,
              child: const Text('Riprova'),
            ),
          ),
        ),
      );
      final scrollable = find.byType(Scrollable);
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(position.maxScrollExtent - 16);
      await tester.pump();
      final button = find.widgetWithText(TextButton, 'Riprova');
      final rect = tester.getRect(button);
      final visible = rect.intersect(tester.getRect(scrollable));
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(visible.height, greaterThan(0));
      expect(visible.height, lessThan(rect.height));
      await tester.tapAt(visible.center);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
