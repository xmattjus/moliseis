import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/app_log_level.dart';

void main() {
  group('LogLevel', () {
    test('enum values are in expected order', () {
      expect(AppLogLevel.values, [
        AppLogLevel.debug,
        AppLogLevel.info,
        AppLogLevel.warning,
        AppLogLevel.error,
        AppLogLevel.critical,
      ]);
    });

    test('index ordering reflects severity', () {
      expect(AppLogLevel.debug.index, lessThan(AppLogLevel.info.index));
      expect(AppLogLevel.info.index, lessThan(AppLogLevel.warning.index));
      expect(AppLogLevel.warning.index, lessThan(AppLogLevel.error.index));
      expect(AppLogLevel.error.index, lessThan(AppLogLevel.critical.index));
    });
  });
}
