import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_identity_section.dart';

void main() {
  testWidgets('technical timestamps use Europe/Rome across DST', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSubmissionMetadataSection(
            contributorName: null,
            contributorEmail: null,
            submissionId: 1,
            createdAt: DateTime.utc(2026, 8, 20, 0, 30, 17).toLocal(),
            modifiedAt: DateTime.utc(2026, 1, 20, 0, 30, 49).toLocal(),
            externalEvent: null,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Autore e dettagli tecnici'));
    await tester.pumpAndSettle();
    expect(
      find.text('Creato il 20/08/2026 02:30:17 (UTC+02:00)'),
      findsOneWidget,
    );
    expect(
      find.text('Modificato il 20/01/2026 01:30:49 (UTC+01:00)'),
      findsOneWidget,
    );
    expect(find.textContaining('2026-08-20 00:30:17.000Z'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (day, firstDisplay, secondDisplay) in [
    (
      DateTime.utc(2026, 10, 25),
      '25/10/2026 02:30:00 (UTC+02:00)',
      '25/10/2026 02:30:00 (UTC+01:00)',
    ),
    (
      DateTime.utc(2026, 3, 29),
      '29/03/2026 01:30:00 (UTC+01:00)',
      '29/03/2026 03:30:00 (UTC+02:00)',
    ),
  ]) {
    testWidgets('technical timestamps distinguish DST instants on $day', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminSubmissionMetadataSection(
              contributorName: null,
              contributorEmail: null,
              submissionId: null,
              createdAt: day.add(const Duration(minutes: 30)),
              modifiedAt: day.add(const Duration(hours: 1, minutes: 30)),
              externalEvent: null,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Autore e dettagli tecnici'));
      await tester.pumpAndSettle();
      expect(find.text('Creato il $firstDisplay'), findsOneWidget);
      expect(find.text('Modificato il $secondDisplay'), findsOneWidget);
      final displayed = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>();
      final created = displayed.singleWhere(
        (text) => text.startsWith('Creato il '),
      );
      final modified = displayed.singleWhere(
        (text) => text.startsWith('Modificato il '),
      );
      expect(
        created.substring('Creato il '.length),
        isNot(modified.substring('Modificato il '.length)),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
