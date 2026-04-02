import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/result.dart';

void main() {
  group('Result helpers', () {
    test('map transforms a successful value', () {
      final result = const Result.success(2).map((value) => value * 3);

      expect(result, isA<Success<int>>());
      expect((result as Success<int>).value, 6);
    });

    test('map preserves the error branch', () {
      final error = _TestException('failed');

      final result = Result<int>.error(error).map((value) => value * 3);

      expect(result, isA<Error<int>>());
      expect((result as Error<int>).error, error);
    });

    test('fold returns the success branch value', () {
      final result = const Result.success(
        'molise',
      ).fold((value) => value.toUpperCase(), (_) => 'fallback');

      expect(result, 'MOLISE');
    });

    test('fold returns the error branch value', () {
      final result = Result<int>.error(
        _TestException('failed'),
      ).fold((value) => value * 2, (error) => error.toString());

      expect(result, 'failed');
    });

    test('fold rethrows when success callback throws', () {
      expect(
        () => const Result.success(2).fold<int>(
          (_) => throw _TestException('success callback failed'),
          (_) => 0,
        ),
        throwsA(isA<_TestException>()),
      );
    });

    test('fold rethrows when error callback throws', () {
      expect(
        () => Result<int>.error(_TestException('failed')).fold<int>(
          (_) => 0,
          (_) => throw _TestException('error callback failed'),
        ),
        throwsA(isA<_TestException>()),
      );
    });

    test('flatMap chains successful results', () {
      final result = const Result.success(
        2,
      ).flatMap((value) => Result.success(value * 4));

      expect(result, isA<Success<int>>());
      expect((result as Success<int>).value, 8);
    });

    test('flatMap preserves the first error', () {
      final error = _TestException('failed');

      final result = Result<int>.error(
        error,
      ).flatMap((value) => Result.success(value * 4));

      expect(result, isA<Error<int>>());
      expect((result as Error<int>).error, error);
    });

    test('flatMap can transform a success into an error', () {
      final error = _TestException('mapped failed');

      final result = const Result.success(
        2,
      ).flatMap<int>((_) => Result.error(error));

      expect(result, isA<Error<int>>());
      expect((result as Error<int>).error, error);
    });

    test('map rethrows when mapper throws', () {
      expect(
        () => const Result.success(2).map<int>((_) {
          throw _TestException('mapper failed');
        }),
        throwsA(isA<_TestException>()),
      );
    });

    test('flatMap rethrows when mapper throws', () {
      expect(
        () => const Result.success(2).flatMap<int>((_) {
          throw _TestException('mapper failed');
        }),
        throwsA(isA<_TestException>()),
      );
    });

    test('getOrNull returns value on success', () {
      final result = const Result.success('molise').getOrNull();
      expect(result, 'molise');
    });

    test('getOrNull returns null on error', () {
      final result = Result<String>.error(_TestException('failed')).getOrNull();
      expect(result, isNull);
    });

    test('getOrElse returns value on success', () {
      final result = const Result.success('molise').getOrElse(() => 'fallback');
      expect(result, 'molise');
    });

    test('getOrElse does not call fallback on success', () {
      var calls = 0;

      final result = const Result.success('molise').getOrElse(() {
        calls++;
        return 'fallback';
      });

      expect(result, 'molise');
      expect(calls, 0);
    });

    test('getOrElse returns default on error', () {
      final result = Result<String>.error(
        _TestException('failed'),
      ).getOrElse(() => 'fallback');
      expect(result, 'fallback');
    });

    test('getOrElse calls fallback exactly once on error', () {
      var calls = 0;

      final result = Result<String>.error(_TestException('failed')).getOrElse(
        () {
          calls++;
          return 'fallback';
        },
      );

      expect(result, 'fallback');
      expect(calls, 1);
    });

    test('isSuccess returns true on success', () {
      expect(const Result.success(42).isSuccess, isTrue);
    });

    test('isSuccess returns false on error', () {
      expect(Result<int>.error(_TestException('failed')).isSuccess, isFalse);
    });

    test('isError returns true on error', () {
      expect(Result<int>.error(_TestException('failed')).isError, isTrue);
    });

    test('isError returns false on success', () {
      expect(const Result.success(42).isError, isFalse);
    });
  });
}

final class _TestException implements Exception {
  _TestException(this.message);

  final String message;

  @override
  String toString() => message;
}
