import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the editor's secondary decisions without scrolling its content form.
Future<void> showAdminEditorActions(WidgetTester tester) async {
  final title = find.text('Altre azioni');
  if (title.evaluate().isEmpty) return;
  if (ExpansibleController.of(tester.element(title)).isExpanded) return;
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
