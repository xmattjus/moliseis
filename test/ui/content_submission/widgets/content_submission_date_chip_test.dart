import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/core/event_time.dart';
import 'package:moliseis/ui/content_submission/widgets/content_submission_date_chip.dart';

void main() {
  testWidgets('Material date picker clamps a cross-year inverted selection', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentSubmissionDateChip.date(
            firstDate: EventCalendarDate(2027, 1, 1),
            selectedDate: EventCalendarDate(2026, 12, 31),
            label: const Text('Data'),
            onDatePicked: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Data'));
    await tester.pump();

    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.initialDate!.isBefore(picker.firstDate), isFalse);
    expect(picker.lastDate.isBefore(picker.firstDate), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS date picker clamps a cross-year inverted selection', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.binding.setSurfaceSize(const Size(375, 600));
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 600)),
          child: Scaffold(
            body: ContentSubmissionDateChip.date(
              firstDate: EventCalendarDate(2027, 1, 1),
              selectedDate: EventCalendarDate(2026, 12, 31),
              label: const Text('Data'),
              onDatePicked: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Data'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    final minimumDate = picker.minimumDate!;
    expect(picker.initialDateTime.isBefore(minimumDate), isFalse);
    expect(picker.maximumDate!.isBefore(minimumDate), isFalse);
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('iOS date picker seeds and emits a semantic calendar date', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.binding.setSurfaceSize(const Size(375, 600));
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });
    EventCalendarDate? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 600)),
          child: Scaffold(
            body: ContentSubmissionDateChip.date(
              selectedDate: EventCalendarDate(2026, 8, 20),
              label: const Text('Data'),
              onDatePicked: (value) => picked = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Data'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(picker.initialDateTime, DateTime(2026, 8, 20));
    await tester.tap(find.text('Conferma'));
    await tester.pump();

    expect(picked, EventCalendarDate(2026, 8, 20));
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('iOS time picker seeds Rome default with rounded minutes', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.binding.setSurfaceSize(const Size(375, 600));
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 600)),
          child: Scaffold(
            body: ContentSubmissionDateChip.time(
              nowUtc: DateTime.utc(2026, 8, 20, 8, 2),
              label: const Text('Ora'),
              onTimePicked: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ora'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );

    expect(picker.initialDateTime, DateTime(2000, 1, 1, 10));
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('non-compact iOS keeps the Material date picker', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Scaffold(
            body: ContentSubmissionDateChip.date(
              selectedDate: EventCalendarDate(2026, 8, 20),
              label: const Text('Data'),
              onDatePicked: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Data'));
    await tester.pump();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Material picker uses selected semantic time', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentSubmissionDateChip.time(
            selectedTime: EventClockTime(14, 35),
            label: const Text('Ora'),
            onTimePicked: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ora'));
    await tester.pump();

    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialTime,
      const TimeOfDay(hour: 14, minute: 35),
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
