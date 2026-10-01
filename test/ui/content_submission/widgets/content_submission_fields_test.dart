import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_date_chip.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';

void main() {
  Widget buildFields({
    required bool isEvent,
    bool allDay = false,
    ValueChanged<bool>? onAllDayChanged,
    EventCalendarDate? startDate,
    EventClockTime? startTime,
    EventCalendarDate? endDate,
    EventTimeIssue? issue,
    ValueChanged<bool>? onEventChanged,
    ValueChanged<EventCalendarDate?>? onStartDateChanged,
    ValueChanged<EventClockTime?>? onStartTimeChanged,
    ValueChanged<EventCalendarDate?>? onEndDateChanged,
  }) => MaterialApp(
    locale: const Locale('it'),
    localizationsDelegates: const [
      FlutterQuillLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: const <Locale>[Locale('en'), Locale('it')],
    home: Scaffold(
      body: SingleChildScrollView(
        child: ContentSubmissionFields(
          formKey: GlobalKey<FormState>(),
          category: null,
          city: null,
          name: null,
          description: null,
          descriptionDelta: null,
          isEvent: isEvent,
          allDay: allDay,
          onAllDayChanged: onAllDayChanged ?? (_) {},
          startCalendarDate: startDate,
          startClockTime: startTime,
          endCalendarDate: endDate,
          eventTimeIssue: issue,
          onCategorySelected: (_) {},
          onCategoryDeleted: () {},
          onCityChanged: (_) {},
          onNameChanged: (_) {},
          onDescriptionChanged:
              ({required description, required descriptionDelta}) {},
          onEventChanged: onEventChanged ?? (_) {},
          onStartDateChanged: onStartDateChanged ?? (_) {},
          onStartTimeChanged: onStartTimeChanged ?? (_) {},
          onEndDateChanged: onEndDateChanged ?? (_) {},
        ),
      ),
    ),
  );

  group('ContentSubmissionFields', () {
    testWidgets('date-only hides clock and toggle off leaves it unresolved', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        buildFields(
          isEvent: true,
          allDay: true,
          startDate: EventCalendarDate(2026, 3, 29),
          endDate: EventCalendarDate(2026, 3, 30),
          onAllDayChanged: changes.add,
        ),
      );
      expect(find.text('Senza orario'), findsOneWidget);
      expect(find.byType(ContentSubmissionDateChip), findsNWidgets(2));
      expect(find.textContaining('Inizia alle'), findsNothing);
      await tester.ensureVisible(find.byType(Checkbox).last);
      await tester.tap(find.byType(Checkbox).last);
      expect(changes, [false]);
      await tester.pumpWidget(
        buildFields(
          isEvent: true,
          startDate: EventCalendarDate(2026, 3, 29),
          endDate: EventCalendarDate(2026, 3, 30),
          issue: EventTimeIssue.missingStartTime,
        ),
      );
      expect(find.text('Seleziona ora di inizio'), findsOneWidget);
      expect(find.textContaining('00:00'), findsNothing);
    });

    testWidgets('renders the shared content sections', (tester) async {
      await tester.pumpWidget(buildFields(isEvent: false));

      expect(find.text('Categoria'), findsOneWidget);
      expect(find.text('Dettagli'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Città'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Luogo o evento'),
        findsOneWidget,
      );
    });

    testWidgets('is controlled by the supplied event state', (tester) async {
      await tester.pumpWidget(buildFields(isEvent: false));
      expect(find.text('Seleziona data di inizio'), findsNothing);

      await tester.pumpWidget(buildFields(isEvent: true));
      expect(find.text('Seleziona data di inizio'), findsOneWidget);
      expect(find.text('Seleziona data di fine'), findsOneWidget);
    });

    testWidgets('sends checkbox changes to its controller', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        buildFields(isEvent: true, onEventChanged: changes.add),
      );

      await tester.tap(find.byType(Checkbox).first);
      expect(changes, <bool>[false]);
    });

    testWidgets('wires semantic chip selections to callbacks', (tester) async {
      final startDates = <EventCalendarDate?>[];
      final startTimes = <EventClockTime?>[];
      final endDates = <EventCalendarDate?>[];
      await tester.pumpWidget(
        buildFields(
          isEvent: true,
          startDate: EventCalendarDate(2026, 8, 20),
          startTime: EventClockTime(10, 30),
          endDate: EventCalendarDate(2026, 8, 20),
          onStartDateChanged: startDates.add,
          onStartTimeChanged: startTimes.add,
          onEndDateChanged: endDates.add,
        ),
      );

      final chips = tester
          .widgetList<ContentSubmissionDateChip>(
            find.byType(ContentSubmissionDateChip),
          )
          .toList();
      expect(chips, hasLength(3));
      chips[0].onDatePicked!(EventCalendarDate(2026, 8, 21));
      chips[1].onTimePicked!(EventClockTime(14, 30));
      chips[2].onDatePicked!(EventCalendarDate(2026, 8, 22));

      expect(startDates, <EventCalendarDate?>[EventCalendarDate(2026, 8, 21)]);
      expect(startTimes, <EventClockTime?>[EventClockTime(14, 30)]);
      expect(endDates, <EventCalendarDate?>[EventCalendarDate(2026, 8, 22)]);
    });

    testWidgets('renders the temporal validation issue in the date section', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildFields(isEvent: true, issue: EventTimeIssue.nonexistentLocalTime),
      );

      expect(find.textContaining('non esiste in Italia'), findsOneWidget);
    });
  });
}
