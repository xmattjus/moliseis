import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/config/service_locator.dart';
import 'package:moliseis/utils/result.dart';

void main() {
  group('handleSettingsRepositoryInitialization', () {
    test('returns success unchanged', () {
      const result = Result.success(null);

      final handledResult = handleSettingsRepositoryInitialization(result);

      expect(handledResult, isA<Success<void>>());
    });

    test('returns error unchanged', () {
      final result = Result.error(_TestException('init failed'));

      final handledResult = handleSettingsRepositoryInitialization(result);

      expect(handledResult, isA<Error<void>>());
    });
  });
}

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
