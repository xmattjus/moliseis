// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

void main() {
  group('SentryLoggingFlag', () {
    test('initializes with enabled = true', () {
      final flag = SentryLoggingFlag(initialValue: true);

      expect(flag.enabled, isTrue);
    });

    test('initializes with enabled = false', () {
      final flag = SentryLoggingFlag(initialValue: false);

      expect(flag.enabled, isFalse);
    });

    test('can be toggled from false to true', () {
      final flag = SentryLoggingFlag(initialValue: false);

      flag.enabled = true;

      expect(flag.enabled, isTrue);
    });

    test('can be toggled from true to false', () {
      final flag = SentryLoggingFlag(initialValue: true);

      flag.enabled = false;

      expect(flag.enabled, isFalse);
    });

    test('setting same value is idempotent', () {
      final flag = SentryLoggingFlag(initialValue: true);

      flag.enabled = true;

      expect(flag.enabled, isTrue);
    });
  });
}
