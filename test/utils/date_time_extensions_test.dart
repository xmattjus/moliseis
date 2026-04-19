import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/extensions/date_time_extensions.dart';

void main() {
  group('DateTimeNullableExtensions', () {
    group('maybeGreaterOrEqualDate', () {
      test('returns false when receiver is null', () {
        DateTime? date;
        expect(date.maybeGreaterOrEqualDate(DateTime(2026, 6)), isFalse);
      });

      test('returns false when other is null', () {
        expect(DateTime(2026, 6).maybeGreaterOrEqualDate(null), isFalse);
      });

      test('returns false when both are null', () {
        DateTime? date;
        expect(date.maybeGreaterOrEqualDate(null), isFalse);
      });

      test('returns true when receiver is after other', () {
        expect(
          DateTime(2026, 6, 2).maybeGreaterOrEqualDate(DateTime(2026, 6)),
          isTrue,
        );
      });

      test('returns true when receiver equals other', () {
        final dt = DateTime(2026, 6, 1, 12, 30);
        expect(dt.maybeGreaterOrEqualDate(dt), isTrue);
      });

      test('returns false when receiver is before other', () {
        expect(
          DateTime(2026, 5, 31).maybeGreaterOrEqualDate(DateTime(2026, 6)),
          isFalse,
        );
      });
    });

    group('maybeLessOrEqualDate', () {
      test('returns false when receiver is null', () {
        DateTime? date;
        expect(date.maybeLessOrEqualDate(DateTime(2026, 6)), isFalse);
      });

      test('returns false when other is null', () {
        expect(DateTime(2026, 6).maybeLessOrEqualDate(null), isFalse);
      });

      test('returns false when both are null', () {
        DateTime? date;
        expect(date.maybeLessOrEqualDate(null), isFalse);
      });

      test('returns true when receiver is before other', () {
        expect(
          DateTime(2026, 5, 31).maybeLessOrEqualDate(DateTime(2026, 6)),
          isTrue,
        );
      });

      test('returns true when receiver equals other', () {
        final dt = DateTime(2026, 6, 1, 12, 30);
        expect(dt.maybeLessOrEqualDate(dt), isTrue);
      });

      test('returns false when receiver is after other', () {
        expect(
          DateTime(2026, 6, 2).maybeLessOrEqualDate(DateTime(2026, 6)),
          isFalse,
        );
      });
    });
  });

  group('DateTimeExtensions', () {
    test('startOfDay resets the time to midnight', () {
      final dateTime = DateTime(2026, 4, 2, 15, 42, 18, 123, 456);

      final startOfDay = dateTime.startOfDay;

      expect(startOfDay, DateTime(2026, 4, 2));
    });

    test('endOfDay sets the time to the last microsecond of the day', () {
      final dateTime = DateTime(2026, 4, 2, 15, 42, 18, 123, 456);

      final endOfDay = dateTime.endOfDay;

      expect(endOfDay, DateTime(2026, 4, 2, 23, 59, 59, 999, 999));
    });

    test('isBeforeNow returns true for past instants', () {
      final dateTime = DateTime.now().subtract(const Duration(minutes: 1));

      expect(dateTime.isBeforeNow, isTrue);
      expect(dateTime.isAfterNow, isFalse);
    });

    test('isAfterNow returns true for future instants', () {
      final dateTime = DateTime.now().add(const Duration(minutes: 1));

      expect(dateTime.isAfterNow, isTrue);
      expect(dateTime.isBeforeNow, isFalse);
    });
  });
}
