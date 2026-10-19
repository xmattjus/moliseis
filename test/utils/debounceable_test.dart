import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/debounceable.dart';

void main() {
  group('Debounced', () {
    test(
      'cancel resolves a pending call without invoking the function',
      () async {
        var invocationCount = 0;
        final debounced = debounce<int, String>(
          duration: const Duration(seconds: 1),
          function: ([query]) async {
            invocationCount++;
            return query?.length;
          },
        );

        final pending = debounced.call('query');
        debounced.cancel();

        expect(await pending, isNull);
        expect(invocationCount, 0);
      },
    );

    test('cancel is safe when no call is pending', () {
      final debounced = debounce<int, void>(
        duration: const Duration(seconds: 1),
        function: ([_]) async => 1,
      );

      expect(debounced.cancel, returnsNormally);
      expect(debounced.cancel, returnsNormally);
    });
    testWidgets('supersession invokes only the latest argument', (
      tester,
    ) async {
      final arguments = <String?>[];
      final debounced = debounce<int, String>(
        duration: const Duration(seconds: 1),
        function: ([query]) async {
          arguments.add(query);
          return query?.length;
        },
      );
      final first = debounced('first');
      final last = debounced('last');

      await tester.pump();
      expect(await first, isNull);
      expect(arguments, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(await last, 4);
      expect(arguments, ['last']);
    });

    testWidgets('cancel after callback starts preserves its pending result', (
      tester,
    ) async {
      final callback = Completer<int?>();
      final arguments = <String?>[];
      final debounced = debounce<int, String>(
        duration: const Duration(seconds: 1),
        function: ([query]) {
          arguments.add(query);
          return callback.future;
        },
      );
      var completed = false;
      final pending = debounced('started');
      unawaited(pending.then((_) => completed = true));
      await tester.pump(const Duration(seconds: 1));
      expect(arguments, ['started']);
      expect(completed, isFalse);
      debounced.cancel();
      await tester.pump();
      expect(completed, isFalse);

      callback.complete(7);
      await tester.pump();
      expect(await pending, 7);
    });

    testWidgets('started callback errors propagate after cancel', (
      tester,
    ) async {
      final callback = Completer<int?>();
      var started = false;
      final debounced = debounce<int, void>(
        duration: const Duration(seconds: 1),
        function: ([_]) {
          started = true;
          return callback.future;
        },
      );
      final error = StateError('callback failed');
      final observed = expectLater(debounced(), throwsA(same(error)));
      await tester.pump(const Duration(seconds: 1));
      expect(started, isTrue);
      debounced.cancel();
      callback.completeError(error);
      await tester.pump();
      await observed;
    });
  });
}
