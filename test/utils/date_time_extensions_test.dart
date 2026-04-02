import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/extensions/date_time_extensions.dart';

void main() {
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
