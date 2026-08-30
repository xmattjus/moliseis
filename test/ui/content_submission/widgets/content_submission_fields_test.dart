import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_date_chip.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';

void main() {
  Widget buildFields({
    required bool isEvent,
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
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      FlutterQuillLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
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

      await tester.tap(find.byType(Checkbox));
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
        buildFields(
          isEvent: true,
          issue: EventTimeIssue.nonexistentLocalTime,
        ),
      );

      expect(find.textContaining('non esiste in Italia'), findsOneWidget);
    });
  });
}
