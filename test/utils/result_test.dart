import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/result.dart';

import '../support/fake_repositories.dart';

void main() {
  group('Result helpers', () {
    test('map transforms a successful value', () {
      final result = const Result.success(2).map((value) => value * 3);

      expect(result, isA<Success<int>>());
      expect((result as Success<int>).value, 6);
    });

    test('map preserves the error branch', () {
      final error = TestException('failed');

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
        TestException('failed'),
      ).fold((value) => value * 2, (error) => error.toString());

      expect(result, 'failed');
    });

    test('fold rethrows when success callback throws', () {
      expect(
        () => const Result.success(2).fold<int>(
          (_) => throw TestException('success callback failed'),
          (_) => 0,
        ),
        throwsA(isA<TestException>()),
      );
    });

    test('fold rethrows when error callback throws', () {
      expect(
        () => Result<int>.error(TestException('failed')).fold<int>(
          (_) => 0,
          (_) => throw TestException('error callback failed'),
        ),
        throwsA(isA<TestException>()),
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
      final error = TestException('failed');

      final result = Result<int>.error(
        error,
      ).flatMap((value) => Result.success(value * 4));

      expect(result, isA<Error<int>>());
      expect((result as Error<int>).error, error);
    });

    test('flatMap can transform a success into an error', () {
      final error = TestException('mapped failed');

      final result = const Result.success(
        2,
      ).flatMap<int>((_) => Result.error(error));

      expect(result, isA<Error<int>>());
      expect((result as Error<int>).error, error);
    });

    test('map rethrows when mapper throws', () {
      expect(
        () => const Result.success(2).map<int>((_) {
          throw TestException('mapper failed');
        }),
        throwsA(isA<TestException>()),
      );
    });

    test('flatMap rethrows when mapper throws', () {
      expect(
        () => const Result.success(2).flatMap<int>((_) {
          throw TestException('mapper failed');
        }),
        throwsA(isA<TestException>()),
      );
    });

    test('getOrNull returns value on success', () {
      final result = const Result.success('molise').getOrNull();
      expect(result, 'molise');
    });

    test('getOrNull returns null on error', () {
      final result = Result<String>.error(TestException('failed')).getOrNull();
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
        TestException('failed'),
      ).getOrElse(() => 'fallback');
      expect(result, 'fallback');
    });

    test('getOrElse calls fallback exactly once on error', () {
      var calls = 0;

      final result = Result<String>.error(TestException('failed')).getOrElse(
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
      expect(Result<int>.error(TestException('failed')).isSuccess, isFalse);
    });

    test('isError returns true on error', () {
      expect(Result<int>.error(TestException('failed')).isError, isTrue);
    });

    test('isError returns false on success', () {
      expect(const Result.success(42).isError, isFalse);
    });

    group('mapError', () {
      test('leaves success unchanged', () {
        final result = const Result.success(
          42,
        ).mapError((_) => TestException('x'));

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).value, 42);
      });

      test('does not call mapper on success', () {
        var calls = 0;

        const Result.success(42).mapError((_) {
          calls++;
          return TestException('x');
        });

        expect(calls, 0);
      });

      test('transforms error with mapper', () {
        final original = TestException('original');
        final mapped = TestException('mapped');

        final result = Result<int>.error(original).mapError((_) => mapped);

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, mapped);
      });

      test('receives the original error in the mapper', () {
        final original = TestException('original');
        Exception? received;

        Result<int>.error(original).mapError((error) {
          received = error;
          return TestException('replacement');
        });

        expect(received, same(original));
      });

      test('rethrows when mapper throws', () {
        expect(
          () => Result<int>.error(TestException('original')).mapError((_) {
            throw TestException('mapper failed');
          }),
          throwsA(isA<TestException>()),
        );
      });
    });

    group('flatMapError', () {
      test('leaves success unchanged', () {
        final result = const Result.success(
          42,
        ).flatMapError((_) => const Result.success(0));

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).value, 42);
      });

      test('does not call mapper on success', () {
        var calls = 0;

        const Result.success(42).flatMapError((_) {
          calls++;
          return const Result.success(0);
        });

        expect(calls, 0);
      });

      test('recovers error to success', () {
        final result = Result<int>.error(
          TestException('failed'),
        ).flatMapError((_) => const Result.success(99));

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).value, 99);
      });

      test('maps error to another error', () {
        final newError = TestException('new error');

        final result = Result<int>.error(
          TestException('original'),
        ).flatMapError((_) => Result.error(newError));

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, newError);
      });

      test('receives the original error in the mapper', () {
        final original = TestException('original');
        Exception? received;

        Result<int>.error(original).flatMapError((error) {
          received = error;
          return const Result.success(0);
        });

        expect(received, same(original));
      });

      test('rethrows when mapper throws', () {
        expect(
          () => Result<int>.error(
            TestException('original'),
          ).flatMapError((_) => throw TestException('mapper failed')),
          throwsA(isA<TestException>()),
        );
      });
    });

    group('asyncFold', () {
      test('returns success branch value', () async {
        final result = await const Result.success('molise').asyncFold(
          (value) => Future.value(value.toUpperCase()),
          (_) => Future.value('error'),
        );

        expect(result, 'MOLISE');
      });

      test('returns error branch value', () async {
        final result = await Result<int>.error(TestException('failed'))
            .asyncFold(
              (value) => Future.value(value * 2),
              (error) => Future.value(error.toString()),
            );

        expect(result, 'failed');
      });

      test('works with sync callbacks', () async {
        final result = await const Result.success(
          42,
        ).asyncFold((value) => value + 1, (_) => 0);

        expect(result, 43);
      });
    });

    group('asyncMap', () {
      test('transforms a successful value asynchronously', () async {
        final result = await const Result.success(
          2,
        ).asyncMap((value) => Future.value(value * 3));

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).value, 6);
      });

      test('preserves the error branch', () async {
        final error = TestException('failed');

        final result = await Result<int>.error(
          error,
        ).asyncMap((value) => Future.value(value * 3));

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, error);
      });

      test('does not call mapper on error', () async {
        var calls = 0;

        await Result<int>.error(TestException('failed')).asyncMap((value) {
          calls++;
          return Future.value(value);
        });

        expect(calls, 0);
      });

      test('works with sync mappers', () async {
        final result = await const Result.success(5).asyncMap((v) => v * 2);

        expect((result as Success<int>).value, 10);
      });
    });

    group('asyncFlatMap', () {
      test('chains successful results asynchronously', () async {
        final result = await const Result.success(
          2,
        ).asyncFlatMap((value) => Future.value(Result.success(value * 4)));

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).value, 8);
      });

      test('preserves the first error', () async {
        final error = TestException('failed');

        final result = await Result<int>.error(
          error,
        ).asyncFlatMap((value) => Future.value(Result.success(value * 4)));

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, error);
      });

      test('can transform a success into an error', () async {
        final error = TestException('mapped failed');

        final result = await const Result.success(
          2,
        ).asyncFlatMap<int>((_) => Future.value(Result.error(error)));

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, error);
      });

      test('does not call mapper on error', () async {
        var calls = 0;

        await Result<int>.error(TestException('failed')).asyncFlatMap((v) {
          calls++;
          return Future.value(Result.success(v));
        });

        expect(calls, 0);
      });
    });

    group('asyncMapError', () {
      test('leaves success unchanged', () async {
        final result = await const Result.success(
          42,
        ).asyncMapError((_) => Future.value(TestException('x')));

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).value, 42);
      });

      test('does not call mapper on success', () async {
        var calls = 0;

        await const Result.success(42).asyncMapError((_) {
          calls++;
          return Future.value(TestException('x'));
        });

        expect(calls, 0);
      });

      test('transforms error with async mapper', () async {
        final mapped = TestException('mapped');

        final result = await Result<int>.error(
          TestException('original'),
        ).asyncMapError((_) => Future.value(mapped));

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, mapped);
      });

      test('receives the original error in the mapper', () async {
        final original = TestException('original');
        Exception? received;

        await Result<int>.error(original).asyncMapError((error) {
          received = error;
          return Future.value(TestException('replacement'));
        });

        expect(received, same(original));
      });
    });

    group('asyncFlatMapError', () {
      test('leaves success unchanged', () async {
        final result = await const Result.success(
          42,
        ).asyncFlatMapError((_) => Future.value(const Result.success(0)));

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).value, 42);
      });

      test('does not call mapper on success', () async {
        var calls = 0;

        await const Result.success(42).asyncFlatMapError((_) {
          calls++;
          return Future.value(const Result.success(0));
        });

        expect(calls, 0);
      });

      test('recovers error to success asynchronously', () async {
        final result = await Result<int>.error(
          TestException('failed'),
        ).asyncFlatMapError((_) => Future.value(const Result.success(99)));

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).value, 99);
      });

      test('maps error to another error asynchronously', () async {
        final newError = TestException('new error');

        final result = await Result<int>.error(
          TestException('original'),
        ).asyncFlatMapError((_) => Future.value(Result.error(newError)));

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, newError);
      });

      test('receives the original error in the mapper', () async {
        final original = TestException('original');
        Exception? received;

        await Result<int>.error(original).asyncFlatMapError((error) {
          received = error;
          return Future.value(const Result.success(0));
        });

        expect(received, same(original));
      });
    });

    group('asyncGetOrElse', () {
      test('returns value on success without calling fallback', () async {
        var calls = 0;

        final result = await const Result.success('molise').asyncGetOrElse(() {
          calls++;
          return Future.value('fallback');
        });

        expect(result, 'molise');
        expect(calls, 0);
      });

      test('returns async default on error', () async {
        final result = await Result<String>.error(
          TestException('failed'),
        ).asyncGetOrElse(() => Future.value('fallback'));

        expect(result, 'fallback');
      });

      test('calls fallback exactly once on error', () async {
        var calls = 0;

        await Result<String>.error(TestException('failed')).asyncGetOrElse(() {
          calls++;
          return Future.value('fallback');
        });

        expect(calls, 1);
      });

      test('works with sync fallback', () async {
        final result = await Result<String>.error(
          TestException('failed'),
        ).asyncGetOrElse(() => 'sync fallback');

        expect(result, 'sync fallback');
      });
    });

    group('zip2', () {
      test('calls onSuccess with both values when both succeed', () async {
        final result = await Result.zip2(
          () async => const Result.success(1),
          () async => const Result.success('molise'),
          (a, b) => Result.success('$a-$b'),
        );

        expect(result, isA<Success<String>>());
        expect((result as Success<String>).value, '1-molise');
      });

      test('short-circuits and propagates a error without calling b', () async {
        final error = TestException('a failed');
        var bCalled = false;

        final result = await Result.zip2(
          () async => Result<int>.error(error),
          () async {
            bCalled = true;
            return const Result.success('molise');
          },
          (a, b) => Result.success('$a-$b'),
        );

        expect(result, isA<Error<String>>());
        expect((result as Error<String>).error, error);
        expect(bCalled, isFalse);
      });

      test('propagates b error without calling onSuccess', () async {
        final error = TestException('b failed');
        var onSuccessCalled = false;

        final result = await Result.zip2(
          () async => const Result.success(1),
          () async => Result<String>.error(error),
          (a, b) {
            onSuccessCalled = true;
            return Result.success('$a-$b');
          },
        );

        expect(result, isA<Error<String>>());
        expect((result as Error<String>).error, error);
        expect(onSuccessCalled, isFalse);
      });

      test('propagates error returned from onSuccess', () async {
        final error = TestException('onSuccess failed');

        final result = await Result.zip2(
          () async => const Result.success(1),
          () async => const Result.success(2),
          (a, b) => Result<String>.error(error),
        );

        expect(result, isA<Error<String>>());
        expect((result as Error<String>).error, error);
      });

      test('propagates exception thrown in onSuccess', () async {
        await expectLater(
          () => Result.zip2<int, int, Exception>(
            () async => const Result.success(1),
            () async => const Result.success(2),
            (a, b) => throw TestException('onSuccess threw'),
          ),
          throwsA(isA<TestException>()),
        );
      });
    });

    group('zip3', () {
      test('calls onSuccess with all three values when all succeed', () async {
        final result = await Result.zip3(
          () async => const Result.success(1),
          () async => const Result.success(2),
          () async => const Result.success(3),
          (a, b, c) => Result.success(a + b + c),
        );

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).value, 6);
      });

      test('short-circuits when a fails, skipping b and c', () async {
        final error = TestException('a failed');
        var bCalled = false;
        var cCalled = false;

        final result = await Result.zip3(
          () async => Result<int>.error(error),
          () async {
            bCalled = true;
            return const Result.success(2);
          },
          () async {
            cCalled = true;
            return const Result.success(3);
          },
          (a, b, c) => Result.success(a + b + c),
        );

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, error);
        expect(bCalled, isFalse);
        expect(cCalled, isFalse);
      });

      test('short-circuits when b fails, skipping c', () async {
        final error = TestException('b failed');
        var cCalled = false;

        final result = await Result.zip3(
          () async => const Result.success(1),
          () async => Result<int>.error(error),
          () async {
            cCalled = true;
            return const Result.success(3);
          },
          (a, b, c) => Result.success(a + b + c),
        );

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, error);
        expect(cCalled, isFalse);
      });

      test('propagates c error', () async {
        final error = TestException('c failed');

        final result = await Result.zip3(
          () async => const Result.success(1),
          () async => const Result.success(2),
          () async => Result<int>.error(error),
          (a, b, c) => Result.success(a + b + c),
        );

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, error);
      });
    });

    group('zip4', () {
      test('calls onSuccess with all four values when all succeed', () async {
        final result = await Result.zip4(
          () async => const Result.success(1),
          () async => const Result.success(2),
          () async => const Result.success(3),
          () async => const Result.success(4),
          (a, b, c, d) => Result.success(a + b + c + d),
        );

        expect(result, isA<Success<int>>());
        expect((result as Success<int>).value, 10);
      });

      test('short-circuits when a fails, skipping b, c and d', () async {
        final error = TestException('a failed');
        var bCalled = false;

        final result = await Result.zip4(
          () async => Result<int>.error(error),
          () async {
            bCalled = true;
            return const Result.success(2);
          },
          () async => const Result.success(3),
          () async => const Result.success(4),
          (a, b, c, d) => Result.success(a + b + c + d),
        );

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, error);
        expect(bCalled, isFalse);
      });

      test('short-circuits when b fails, skipping c and d', () async {
        final error = TestException('b failed');
        var cCalled = false;

        final result = await Result.zip4(
          () async => const Result.success(1),
          () async => Result<int>.error(error),
          () async {
            cCalled = true;
            return const Result.success(3);
          },
          () async => const Result.success(4),
          (a, b, c, d) => Result.success(a + b + c + d),
        );

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, error);
        expect(cCalled, isFalse);
      });

      test('short-circuits when c fails, skipping d', () async {
        final error = TestException('c failed');
        var dCalled = false;

        final result = await Result.zip4(
          () async => const Result.success(1),
          () async => const Result.success(2),
          () async => Result<int>.error(error),
          () async {
            dCalled = true;
            return const Result.success(4);
          },
          (a, b, c, d) => Result.success(a + b + c + d),
        );

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, error);
        expect(dCalled, isFalse);
      });

      test('propagates d error', () async {
        final error = TestException('d failed');

        final result = await Result.zip4(
          () async => const Result.success(1),
          () async => const Result.success(2),
          () async => const Result.success(3),
          () async => Result<int>.error(error),
          (a, b, c, d) => Result.success(a + b + c + d),
        );

        expect(result, isA<Error<int>>());
        expect((result as Error<int>).error, error);
      });
    });
  });
}
