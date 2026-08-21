import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_date_chip.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_fields.dart';

void main() {
  group('ContentSubmissionFields', () {
    late ContentCategory? category;
    late String? city;
    late String? name;
    late String? currentDescription;
    late List<Map<String, dynamic>>? currentDescriptionDelta;
    late DateTime? startDate;
    late DateTime? endDate;
    late List<DateTime?> startDateChanges;
    late List<DateTime?> startTimeChanges;
    late List<DateTime?> endDateChanges;
    late GlobalKey<FormState> formKey;
    late Widget fields;

    setUp(() {
      category = null;
      city = null;
      name = null;
      currentDescription = null;
      currentDescriptionDelta = null;
      startDate = null;
      endDate = null;
      startDateChanges = <DateTime?>[];
      startTimeChanges = <DateTime?>[];
      endDateChanges = <DateTime?>[];
      formKey = GlobalKey<FormState>();
      fields = MaterialApp(
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
            child: Builder(
              builder: (_) {
                return ContentSubmissionFields(
                  formKey: formKey,
                  category: category,
                  city: city,
                  name: name,
                  description: currentDescription,
                  descriptionDelta: currentDescriptionDelta,
                  startDate: startDate,
                  endDate: endDate,
                  onCategorySelected: (value) => category = value,
                  onCategoryDeleted: () => category = null,
                  onCityChanged: (value) => city = value,
                  onNameChanged: (value) => name = value,
                  onDescriptionChanged:
                      ({
                        required description,
                        required descriptionDelta,
                      }) {
                        currentDescription = description;
                        currentDescriptionDelta = descriptionDelta;
                      },
                  onStartDateChanged: (value) {
                    startDateChanges.add(value);
                    startDate = value;
                  },
                  onStartTimeChanged: (value) {
                    startTimeChanges.add(value);
                    startDate = value;
                  },
                  onEndDateChanged: (value) {
                    endDateChanges.add(value);
                    endDate = value;
                  },
                );
              },
            ),
          ),
        ),
      );
    });

    testWidgets('renders the shared content sections', (tester) async {
      await tester.pumpWidget(fields);

      expect(find.text('Categoria'), findsOneWidget);
      expect(find.text('Dettagli'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Città'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Luogo o evento'),
        findsOneWidget,
      );
    });

    testWidgets('shows the supplied city and name values', (tester) async {
      city = 'Isernia';
      name = 'Museo del Tartufo';

      await tester.pumpWidget(fields);

      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Città'))
            .initialValue,
        'Isernia',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Luogo o evento'),
            )
            .initialValue,
        'Museo del Tartufo',
      );
    });

    testWidgets('propagates edited city values through its callback', (
      tester,
    ) async {
      await tester.pumpWidget(fields);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Città'),
        'Campobasso',
      );
      await tester.pump();

      expect(city, 'Campobasso');
    });

    testWidgets('shows date chips after enabling the event flag', (
      tester,
    ) async {
      await tester.pumpWidget(fields);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(find.text('Seleziona data di inizio'), findsOneWidget);
      expect(find.text('Seleziona data di fine'), findsOneWidget);
    });

    testWidgets('clears both dates after disabling the event flag', (
      tester,
    ) async {
      startDate = DateTime.utc(2026, 8, 20, 10);
      endDate = DateTime.utc(2026, 8, 20, 12);

      await tester.pumpWidget(fields);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(startDateChanges, <DateTime?>[null]);
      expect(endDateChanges, <DateTime?>[null]);
    });

    testWidgets('wires date-chip selections to their callbacks', (
      tester,
    ) async {
      startDate = DateTime.utc(2026, 8, 20, 10);
      endDate = DateTime.utc(2026, 8, 20, 12);

      await tester.pumpWidget(fields);

      final chips = tester
          .widgetList<ContentSubmissionDateChip>(
            find.byType(ContentSubmissionDateChip),
          )
          .toList();
      final selectedStartDate = DateTime.utc(2026, 8, 21, 9);
      final selectedStartTime = DateTime.utc(2026, 8, 21, 14, 30);
      final selectedEndDate = DateTime.utc(2026, 8, 22, 17);

      expect(chips, hasLength(3));
      chips[0].onDatePicked(selectedStartDate);
      chips[1].onDatePicked(selectedStartTime);
      chips[2].onDatePicked(selectedEndDate);

      expect(startDateChanges, <DateTime?>[selectedStartDate]);
      expect(startTimeChanges, <DateTime?>[selectedStartTime]);
      expect(endDateChanges, <DateTime?>[selectedEndDate]);
    });
  });
}
