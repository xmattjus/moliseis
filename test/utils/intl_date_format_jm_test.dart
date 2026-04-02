import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' as intl;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it');
    await initializeDateFormatting('en');
  });

  group('intl.DateFormat.jm', () {
    test('formats it-IT time in 24-hour format', () {
      final formatted = intl.DateFormat.jm(
        'it-IT',
      ).format(DateTime(2026, 4, 2, 17, 8));

      expect(formatted, '17:08');
    });

    test('formats en-EN time in 12-hour format', () {
      final formatted = intl.DateFormat.jm(
        'en-EN',
      ).format(DateTime(2026, 4, 2, 17, 8));

      final normalized = formatted
          .replaceAll('\u00A0', ' ')
          .replaceAll('\u202F', ' ');

      expect(
        normalized,
        matches(RegExp(r'^5:08\s?[AP]M$', caseSensitive: false)),
      );
    });
  });
}
