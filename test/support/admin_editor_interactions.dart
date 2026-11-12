import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the complete decision surface only when space requires it.
Future<void> openAdminEditorDecisions(WidgetTester tester) async {
  final open = find.byKey(const ValueKey('admin_open_decisions'));
  if (open.evaluate().isNotEmpty &&
      tester.widget<Tooltip>(open).message != 'Torna al contenuto') {
    await tester.tap(open);
    await tester.pumpAndSettle();
  }
}

/// Opens the editor's secondary decisions without scrolling its content form.
Future<void> showAdminEditorActions(WidgetTester tester) async {
  await openAdminEditorDecisions(tester);
  final title = find.text('Altre azioni');
  if (title.evaluate().isEmpty) return;
  final toggle = find.byKey(const ValueKey('admin_secondary_toggle'));
  if (tester.widget<Semantics>(toggle).properties.expanded == true) return;
  await tester.ensureVisible(title);
  await tester.pumpAndSettle();
  await tester.tap(title);
  await tester.pumpAndSettle();
}

/// Reveals a mounted editor field or an action in its owning scroll surface.
Future<void> revealAdminEditorWidget(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await showAdminEditorActions(tester);
  }
  final open = find.byKey(const ValueKey('admin_open_decisions'));
  final inContent = find.ancestor(
    of: finder,
    matching: find.byKey(const ValueKey('admin_submission_editor_scroll')),
  );
  if (open.evaluate().isNotEmpty &&
      tester.widget<Tooltip>(open).message == 'Torna al contenuto' &&
      (finder.evaluate().isEmpty || inContent.evaluate().isNotEmpty)) {
    await tester.tap(open);
    await tester.pumpAndSettle();
  }
  if (finder.evaluate().isEmpty) {
    final details = find.text('Autore e dettagli tecnici', skipOffstage: false);
    if (details.evaluate().isNotEmpty) {
      if (!ExpansibleController.of(tester.element(details)).isExpanded) {
        await tester.ensureVisible(details);
        await tester.pumpAndSettle();
        await tester.tap(details);
        await tester.pumpAndSettle();
      }
    }
  }
  if (finder.evaluate().isEmpty) {
    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('admin_submission_editor_scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}
