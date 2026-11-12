import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/admin/submissions/widgets/admin_submission_identity_section.dart';

void main() {
  testWidgets('technical timestamps use Europe/Rome across DST', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminSubmissionMetadataSection(
            contributorName: null,
            contributorEmail: null,
            submissionId: 1,
            createdAt: null,
            modifiedAt: null,
            externalEvent: null,
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSubmissionMetadataSection(
            contributorName: null,
            contributorEmail: null,
            submissionId: 1,
            createdAt: DateTime.utc(2026, 8, 20, 0, 30),
            modifiedAt: DateTime.utc(2026, 1, 20, 0, 30),
            externalEvent: null,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Autore e dettagli tecnici'));
    await tester.pumpAndSettle();
    expect(find.text('Creato il 20/08/2026 02:30 (ora di Roma)'), findsOneWidget);
    expect(find.text('Modificato il 20/01/2026 01:30 (ora di Roma)'), findsOneWidget);
    expect(find.textContaining('2026-08-20 00:30:00.000Z'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
