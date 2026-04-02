// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' as intl;
import 'package:latlong2/latlong.dart';
import 'package:moliseis/data/sources/city.dart';
import 'package:moliseis/data/sources/media.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/event_content.dart';
import 'package:moliseis/ui/event/widgets/components/event_formatted_date_time.dart';
import 'package:objectbox/objectbox.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('it');
  });

  group('EventFormattedDateTime', () {
    Future<void> pumpDateTime(
      WidgetTester tester,
      EventContent event, {
      Locale locale = const Locale('en'),
      bool alwaysUse24HourFormat = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const <Locale>[Locale('en'), Locale('it')],
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              alwaysUse24HourFormat: alwaysUse24HourFormat,
            ),
            child: Scaffold(body: EventFormattedDateTime(event: event)),
          ),
        ),
      );

      await tester.pumpAndSettle();
    }

    testWidgets('renders single-day event with one date and one time', (
      WidgetTester tester,
    ) async {
      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 10, 10, 15),
      );

      await pumpDateTime(tester, event);

      final month = intl.DateFormat.MMMM('en').format(event.startDate);
      final time = _formatTimeOfDay(tester, event.startDate);

      expect(find.text('${event.startDate.day} $month'), findsOneWidget);
      expect(find.text(time), findsOneWidget);
    });

    testWidgets('renders same-day event range with end time', (
      WidgetTester tester,
    ) async {
      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 10, 10, 15),
        endDate: DateTime(2026, 4, 10, 12, 45),
      );

      await pumpDateTime(tester, event);

      final month = intl.DateFormat.MMMM('en').format(event.startDate);
      final startTime = _formatTimeOfDay(tester, event.startDate);
      final endTime = _formatTimeOfDay(tester, event.endDate!);

      expect(find.text('${event.startDate.day} $month'), findsOneWidget);
      expect(find.text('$startTime - $endTime'), findsOneWidget);
    });

    testWidgets('renders time range when minutes differ in same hour', (
      WidgetTester tester,
    ) async {
      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 10, 10, 15),
        endDate: DateTime(2026, 4, 10, 10, 45),
      );

      await pumpDateTime(tester, event);

      final startTime = _formatTimeOfDay(tester, event.startDate);
      final endTime = _formatTimeOfDay(tester, event.endDate!);

      expect(find.text('$startTime - $endTime'), findsOneWidget);
    });

    testWidgets('uses 24-hour time format when requested by MediaQuery', (
      WidgetTester tester,
    ) async {
      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 10, 13, 5),
        endDate: DateTime(2026, 4, 10, 14, 10),
      );

      await pumpDateTime(tester, event, alwaysUse24HourFormat: true);

      final startTime = _formatTimeOfDay(
        tester,
        event.startDate,
        alwaysUse24HourFormat: true,
      );
      final endTime = _formatTimeOfDay(
        tester,
        event.endDate!,
        alwaysUse24HourFormat: true,
      );

      expect(find.text('$startTime - $endTime'), findsOneWidget);
    });

    testWidgets('applies custom icon and text colors', (
      WidgetTester tester,
    ) async {
      const iconColor = Color(0xFF123456);
      const textColor = Color(0xFF654321);

      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 10, 10, 15),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: Scaffold(
              body: EventFormattedDateTime(
                event: event,
                iconColor: iconColor,
                textColor: textColor,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final month = intl.DateFormat.MMMM('en').format(event.startDate);
      final time = _formatTimeOfDay(tester, event.startDate);

      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons, hasLength(2));
      expect(icons.every((icon) => icon.color == iconColor), isTrue);

      final dateText = tester.widget<Text>(
        find.text('${event.startDate.day} $month'),
      );
      final timeText = tester.widget<Text>(find.text(time));

      expect(dateText.style?.color, textColor);
      expect(timeText.style?.color, textColor);
    });

    testWidgets('updates month labels when the locale changes', (
      WidgetTester tester,
    ) async {
      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 10, 10, 15),
      );

      await pumpDateTime(tester, event, locale: const Locale('en'));

      final englishMonth = intl.DateFormat.MMMM('en').format(event.startDate);
      expect(find.text('${event.startDate.day} $englishMonth'), findsOneWidget);

      await pumpDateTime(tester, event, locale: const Locale('it'));

      final italianMonth = intl.DateFormat.MMMM('it').format(event.startDate);
      expect(find.text('${event.startDate.day} $italianMonth'), findsOneWidget);
    });

    testWidgets('renders multi-day event in same month', (
      WidgetTester tester,
    ) async {
      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 10, 10, 15),
        endDate: DateTime(2026, 4, 12, 12, 45),
      );

      await pumpDateTime(tester, event);

      final month = intl.DateFormat.MMMM('en').format(event.startDate);
      final startTime = _formatTimeOfDay(tester, event.startDate);
      final endTime = _formatTimeOfDay(tester, event.endDate!);

      expect(
        find.text('${event.startDate.day} - ${event.endDate!.day} $month'),
        findsOneWidget,
      );
      expect(find.text('$startTime - $endTime'), findsOneWidget);
    });

    testWidgets('renders multi-month and multi-year date ranges', (
      WidgetTester tester,
    ) async {
      final multiMonth = _buildEventContent(
        startDate: DateTime(2026, 4, 30, 10, 15),
        endDate: DateTime(2026, 5, 2, 12, 45),
      );

      await pumpDateTime(tester, multiMonth);

      final startMonth = intl.DateFormat.MMMM(
        'en',
      ).format(multiMonth.startDate);
      final endMonth = intl.DateFormat.MMMM('en').format(multiMonth.endDate!);

      expect(
        find.text(
          '${multiMonth.startDate.day} $startMonth - '
          '${multiMonth.endDate!.day} $endMonth',
        ),
        findsOneWidget,
      );

      final multiYear = _buildEventContent(
        startDate: DateTime(2026, 12, 31, 23, 0),
        endDate: DateTime(2027, 1, 2, 8, 30),
      );

      await pumpDateTime(tester, multiYear);

      final startYearMonth =
          '${intl.DateFormat.MMMM('en').format(multiYear.startDate)} '
          '${multiYear.startDate.year}';
      final endYearMonth =
          '${intl.DateFormat.MMMM('en').format(multiYear.endDate!)} '
          '${multiYear.endDate!.year}';

      expect(
        find.text(
          '${multiYear.startDate.day} $startYearMonth - '
          '${multiYear.endDate!.day} $endYearMonth',
        ),
        findsOneWidget,
      );
    });

    testWidgets('normalizes inverted start and end dates', (
      WidgetTester tester,
    ) async {
      final event = _buildEventContent(
        startDate: DateTime(2026, 4, 12, 18, 0),
        endDate: DateTime(2026, 4, 10, 9, 30),
      );

      await pumpDateTime(tester, event);

      final normalizedStart = event.endDate!;
      final normalizedEnd = event.startDate;
      final month = intl.DateFormat.MMMM('en').format(normalizedStart);
      final startTime = _formatTimeOfDay(tester, normalizedStart);
      final endTime = _formatTimeOfDay(tester, normalizedEnd);

      expect(
        find.text('${normalizedStart.day} - ${normalizedEnd.day} $month'),
        findsOneWidget,
      );
      expect(find.text('$startTime - $endTime'), findsOneWidget);
    });
  });
}

String _formatTimeOfDay(
  WidgetTester tester,
  DateTime time, {
  bool alwaysUse24HourFormat = false,
}) {
  final context = tester.element(find.byType(EventFormattedDateTime));
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(time),
    alwaysUse24HourFormat: alwaysUse24HourFormat,
  );
}

EventContent _buildEventContent({
  required DateTime startDate,
  DateTime? endDate,
}) {
  return EventContent(
    category: ContentCategory.experience,
    city: ToOne<City>(),
    coordinates: const LatLng(0.0, 0.0),
    createdAt: DateTime(2026, 1, 1),
    description: 'Test event',
    media: ToMany<Media>(),
    modifiedAt: DateTime(2026, 1, 1),
    name: 'Event',
    remoteId: 1,
    isSaved: false,
    startDate: startDate,
    endDate: endDate,
  );
}
