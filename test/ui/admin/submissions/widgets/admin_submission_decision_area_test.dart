import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_decision_area.dart';

import '../../../../support/typography_harness.dart';
import '../../../../support/typography_measurement_harness.dart';

void main() {
  setUpAll(loadTypographyMeasurementFont);
  for (final scale in [1.0, 2.0]) {
    for (final expanded in [false, true]) {
      testWidgets('combined risks and complete secondary target survive '
          '${expanded ? 'expanded' : 'compact'} constraints at scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(expanded ? 1200 : 320, 500);
        tester.view.viewInsets = const FakeViewPadding(bottom: 100);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        try {
          var applied = 0;
          var rejected = 0;
          var reviewedOverwrite = 0;
          var reviewedSource = 0;
          await tester.pumpWidget(
            typographyHarness(
              child: Scaffold(
                body: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      const Expanded(
                        child: SingleChildScrollView(
                          primary: false,
                          child: Text('Contenuto lungo da verificare'),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: expanded ? 360 * scale : 320,
                          maxHeight: constraints.maxHeight - 48,
                        ),
                        child: AdminSubmissionDecisionArea(
                          expanded: expanded,
                          primaryAction: FilledButton(
                            onPressed: () => applied++,
                            child: const Text('Applica aggiornamento'),
                          ),
                          secondaryActions: [
                            FilledButton.tonal(
                              onPressed: () => rejected++,
                              child: const Text('Rifiuta'),
                            ),
                            for (var index = 0; index < 8; index++)
                              TextButton(
                                onPressed: () {},
                                child: Text('Azione secondaria $index'),
                              ),
                          ],
                          overwriteCount: 1,
                          sourceStale: true,
                          onReviewOverwrites: () => reviewedOverwrite++,
                          onReviewSource: () => reviewedSource++,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final primary = find.widgetWithText(
            FilledButton,
            'Applica aggiornamento',
          );
          expect(primary.hitTestable(), findsOneWidget);
          expect(find.text('Applica aggiornamento'), findsOneWidget);
          final toggle = find.byKey(const ValueKey('admin_secondary_toggle'));
          if (tester.widget<Semantics>(toggle).properties.expanded != true) {
            await tester.tap(find.text('Altre azioni'));
            await tester.pumpAndSettle();
          }
          expect(tester.widget<Semantics>(toggle).properties.expanded, isTrue);
          expect(primary.hitTestable(), findsOneWidget);
          final secondaryViewport = find.byKey(
            const ValueKey('admin_decision_secondary_scroll'),
          );
          final secondary = find.widgetWithText(FilledButton, 'Rifiuta');
          final viewport = tester.getRect(secondaryViewport);
          final target = tester.getRect(secondary);
          expect(target.height, greaterThanOrEqualTo(48));
          expect(viewport.contains(target.topLeft), isTrue);
          expect(
            viewport.contains(target.bottomRight - const Offset(.01, .01)),
            isTrue,
          );
          expect(secondary.hitTestable(), findsOneWidget);
          expect(find.bySemanticsLabel('Rifiuta'), findsOneWidget);
          expect(
            tester.widget<SingleChildScrollView>(secondaryViewport).primary,
            isFalse,
          );
          final risks = find.byKey(const ValueKey('admin_decision_risks'));
          expect(risks.hitTestable(), findsOneWidget);
          expect(
            find.textContaining('1 sovrascrittura').hitTestable(),
            findsOneWidget,
          );
          expect(
            find
                .textContaining(
                  RegExp('fonte (aggiornata|nuova)', caseSensitive: false),
                )
                .hitTestable(),
            findsOneWidget,
          );
          await tester.tap(risks);
          await tester.pumpAndSettle();
          expect(
            find.text('Esamina sovrascritture').hitTestable(),
            findsOneWidget,
          );
          await tester.tap(find.text('Esamina sovrascritture'));
          await tester.pumpAndSettle();
          expect(reviewedOverwrite, 1);
          expect(reviewedSource, 0);
          expect(applied, 0);
          expect(rejected, 0);
          expect(primary.hitTestable(), findsOneWidget);
          await tester.tap(risks);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Esamina fonte aggiornata'));
          await tester.pumpAndSettle();
          expect(reviewedSource, 1);
          expect(applied, 0);
          expect(rejected, 0);
          await tester.tap(secondary);
          await tester.pumpAndSettle();
          expect(rejected, 1);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets('ample decision space exposes both evidence actions directly', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var overwriteReviews = 0;
    var sourceReviews = 0;
    await tester.pumpWidget(
      typographyHarness(
        child: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 360,
              height: 800,
              child: AdminSubmissionDecisionArea(
                expanded: true,
                primaryAction: FilledButton(
                  onPressed: () {},
                  child: const Text('Applica aggiornamento'),
                ),
                secondaryActions: [
                  TextButton(onPressed: () {}, child: const Text('Rifiuta')),
                ],
                overwriteCount: 2,
                sourceStale: true,
                onReviewOverwrites: () => overwriteReviews++,
                onReviewSource: () => sourceReviews++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Applica aggiornamento').hitTestable(), findsOneWidget);
    expect(find.text('Esamina sovrascritture').hitTestable(), findsOneWidget);
    expect(find.text('Esamina fonte aggiornata').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Esamina sovrascritture'));
    await tester.tap(find.text('Esamina fonte aggiornata'));
    expect(overwriteReviews, 1);
    expect(sourceReviews, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile primary scrolling and panel scrolling stay independent', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final primary = ScrollController();
      final backFocus = FocusNode();
      final panelFocus = FocusNode();
      addTearDown(primary.dispose);
      addTearDown(backFocus.dispose);
      addTearDown(panelFocus.dispose);
      await tester.pumpWidget(
        typographyHarness(
          child: PrimaryScrollController(
            controller: primary,
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  focusNode: backFocus,
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      key: const ValueKey('main_content'),
                      slivers: [
                        SliverList.list(
                          children: [
                            for (var index = 0; index < 50; index++)
                              SizedBox(
                                height: 48,
                                child: Text('Contenuto $index'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 300,
                    child: AdminSubmissionDecisionArea(
                      expanded: true,
                      primaryAction: FilledButton(
                        onPressed: () {},
                        child: const Text('Salva modifiche'),
                      ),
                      secondaryActions: [
                        for (var index = 0; index < 20; index++)
                          TextButton(
                            focusNode: index == 0 ? panelFocus : null,
                            onPressed: () {},
                            child: Text('Azione $index'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(primary.positions, hasLength(1));
      final panel = find.byKey(
        const ValueKey('admin_decision_secondary_scroll'),
      );
      final panelScrollable = tester.state<ScrollableState>(
        find.descendant(of: panel, matching: find.byType(Scrollable)).first,
      );
      expect(panelScrollable.position, isNot(same(primary.position)));
      backFocus.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      final bodyAfterDown = primary.offset;
      expect(bodyAfterDown, greaterThan(0));
      expect(panelScrollable.position.pixels, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(primary.offset, lessThan(bodyAfterDown));
      panelFocus.requestFocus();
      await tester.pumpAndSettle();
      final bodyBeforePanelScroll = primary.offset;
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(panelScrollable.position.pixels, greaterThan(0));
      expect(primary.offset, bodyBeforePanelScroll);
      await tester.drag(panel, const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(primary.offset, bodyBeforePanelScroll);
      expect(find.text('Salva modifiche').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
