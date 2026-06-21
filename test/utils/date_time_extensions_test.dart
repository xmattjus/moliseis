import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
    setUpAll(() async {
      await initializeDateFormatting('it');
      await initializeDateFormatting('en');
    });

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

    group('intl.DateFormat.jm', () {
      test('formats it-IT time in 24-hour format', () {
        final dateTime = DateTime(2026, 4, 2, 17, 8);

        final formatted = dateTime.formatTime(const Locale('it', 'IT'));

        expect(formatted, '17:08');
      });

      test('formats en-EN time in 12-hour format', () {
        final dateTime = DateTime(2026, 4, 2, 17, 8);

        final formatted = dateTime.formatTime(const Locale('en', 'US'));

        final normalized = formatted
            .replaceAll('\u00A0', ' ')
            .replaceAll('\u202F', ' ');

        expect(
          normalized,
          matches(RegExp(r'^5:08\s?[AP]M$', caseSensitive: false)),
        );
      });

      test(
        'formats en-EN time in 24-hour format with alwaysUse24HourFormat set '
        'to true',
        () {
          final dateTime = DateTime(2026, 4, 2, 17, 8);

          final formatted = dateTime.formatTime(
            const Locale('en', 'US'),
            alwaysUse24HourFormat: true,
          );

          expect(formatted, '17:08');
        },
      );

      test(
        'formats it-IT time in 24-hour format with alwaysUse24HourFormat set '
        'to true',
        () {
          final dateTime = DateTime(2026, 4, 2, 17, 8);

          final formatted = dateTime.formatTime(
            const Locale('it', 'IT'),
            alwaysUse24HourFormat: true,
          );

          expect(formatted, '17:08');
        },
      );
    });

    group('intl.DateFormat.yMd', () {
      test('formats it-IT date in day/month/year order', () {
        final dateTime = DateTime(2026, 4, 2);

        final formatted = dateTime.formatDate(const Locale('it', 'IT'));

        expect(formatted, '02/04/2026');
      });

      test('formats en-US date in month/day/year order', () {
        final dateTime = DateTime(2026, 4, 2);

        final formatted = dateTime.formatDate(const Locale('en', 'US'));

        expect(formatted, '4/2/2026');
      });

      test('pads single-digit day and month for it-IT', () {
        final dateTime = DateTime(2026, 1, 5);

        final formatted = dateTime.formatDate(const Locale('it', 'IT'));

        expect(formatted, '05/01/2026');
      });
    });

    group('intl.DateFormat.MMMM', () {
      test('localizes month name to it-IT', () {
        final dateTime = DateTime(2026, 4, 2);

        final formatted = dateTime.localizeMonth(const Locale('it', 'IT'));

        expect(formatted, 'aprile');
      });

      test('localizes month name to en-US', () {
        final dateTime = DateTime(2026, 4, 2);

        final formatted = dateTime.localizeMonth(const Locale('en', 'US'));

        expect(formatted, 'April');
      });

      test('localizes January correctly for it-IT', () {
        final dateTime = DateTime(2026, 1, 15);

        final formatted = dateTime.localizeMonth(const Locale('it', 'IT'));

        expect(formatted, 'gennaio');
      });
    });
  });
}
