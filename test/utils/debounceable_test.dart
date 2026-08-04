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
  });
}
