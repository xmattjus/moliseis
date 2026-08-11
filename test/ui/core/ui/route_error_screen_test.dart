import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

import '../../../support/mock_logger.dart';

void main() {
  group('RouteErrorScreen logging', () {
    testWidgets('logs one route error event with uri and error', (
      tester,
    ) async {
      final logger = MockLogger();
      final error = GoException('no routes for location: /bogus');

      await tester.pumpWidget(
        Provider<Logger>.value(
          value: logger,
          child: MaterialApp(
            home: RouteErrorScreen(uri: Uri.parse('/bogus'), error: error),
          ),
        ),
      );

      final call = logger.firstCallOfType<RouteErrorScreenShown>();
      expect(call, isNotNull);

      final event = call!.event as RouteErrorScreenShown;
      expect(event.uri, '/bogus');
      expect(event.reason, error.toString());
      expect(call.error, same(error));
      expect(call.stackTrace, isNull);
      expect(logger.calls, hasLength(1));
    });

    testWidgets('does not log when no logger is available', (tester) async {
      await tester.pumpWidget(
        Provider<Logger?>.value(
          value: null,
          child: MaterialApp(
            home: RouteErrorScreen(
              uri: Uri.parse('/bogus'),
              error: GoException('no routes for location: /bogus'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'logs once per distinct displayed failure on the same state',
      (tester) async {
        final logger = MockLogger();
        final screenKey = GlobalKey<State<RouteErrorScreen>>();
        const sharedReason = 'Unmatched route';

        final firstError = GoException(sharedReason);
        await tester.pumpWidget(
          _buildApp(
            logger: logger,
            screenKey: screenKey,
            uri: Uri.parse('/invalid-one'),
            error: firstError,
          ),
        );

        final initialState = screenKey.currentState;
        expect(initialState, isNotNull);
        expect(logger.calls, hasLength(1));
        expect(
          (logger.calls.first.event as RouteErrorScreenShown).uri,
          '/invalid-one',
        );
        expect(logger.calls.first.error, same(firstError));
        expect(logger.calls.first.stackTrace, isNull);

        await tester.pumpWidget(
          _buildApp(
            logger: logger,
            screenKey: screenKey,
            uri: Uri.parse('/invalid-one'),
            error: GoException(sharedReason),
          ),
        );

        expect(screenKey.currentState, same(initialState));
        expect(logger.calls, hasLength(1));

        final uriChangedError = GoException(sharedReason);
        await tester.pumpWidget(
          _buildApp(
            logger: logger,
            screenKey: screenKey,
            uri: Uri.parse('/invalid-two'),
            error: uriChangedError,
          ),
        );

        expect(screenKey.currentState, same(initialState));
        expect(logger.calls, hasLength(2));
        expect(
          (logger.calls[1].event as RouteErrorScreenShown).uri,
          '/invalid-two',
        );
        expect(
          (logger.calls[1].event as RouteErrorScreenShown).reason,
          uriChangedError.toString(),
        );
        expect(logger.calls[1].error, same(uriChangedError));
        expect(logger.calls[1].stackTrace, isNull);

        final reasonChangedError = GoException('Malformed content id');
        await tester.pumpWidget(
          _buildApp(
            logger: logger,
            screenKey: screenKey,
            uri: Uri.parse('/invalid-two'),
            error: reasonChangedError,
          ),
        );

        expect(screenKey.currentState, same(initialState));
        expect(logger.calls, hasLength(3));
        expect(
          (logger.calls[2].event as RouteErrorScreenShown).uri,
          '/invalid-two',
        );
        expect(
          (logger.calls[2].event as RouteErrorScreenShown).reason,
          reasonChangedError.toString(),
        );
        expect(logger.calls[2].error, same(reasonChangedError));
        expect(logger.calls[2].stackTrace, isNull);
      },
    );

    testWidgets(
      'does not throw on update when the nullable logger value is null',
      (tester) async {
        final screenKey = GlobalKey<State<RouteErrorScreen>>();

        await tester.pumpWidget(
          _buildApp(
            logger: null,
            screenKey: screenKey,
            uri: Uri.parse('/first'),
            error: GoException('first'),
          ),
        );

        final initialState = screenKey.currentState;
        expect(initialState, isNotNull);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _buildApp(
            logger: null,
            screenKey: screenKey,
            uri: Uri.parse('/second'),
            error: GoException('second'),
          ),
        );

        expect(screenKey.currentState, same(initialState));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'logs again when the error type changes even if the reason matches',
      (tester) async {
        final logger = MockLogger();
        final screenKey = GlobalKey<State<RouteErrorScreen>>();
        const sharedReason = 'Unmatched route';

        await tester.pumpWidget(
          _buildApp(
            logger: logger,
            screenKey: screenKey,
            uri: Uri.parse('/invalid'),
            error: GoException(sharedReason),
          ),
        );

        final initialState = screenKey.currentState;
        expect(initialState, isNotNull);
        expect(logger.calls, hasLength(1));

        final secondError = _GoExceptionMimic(sharedReason);
        await tester.pumpWidget(
          _buildApp(
            logger: logger,
            screenKey: screenKey,
            uri: Uri.parse('/invalid'),
            error: secondError,
          ),
        );

        expect(screenKey.currentState, same(initialState));
        expect(logger.calls, hasLength(2));
        expect(
          (logger.calls[1].event as RouteErrorScreenShown).reason,
          GoException(sharedReason).toString(),
        );
        expect(logger.calls[1].error, same(secondError));
      },
    );
  });
}

Widget _buildApp({
  required Logger? logger,
  required GlobalKey<State<RouteErrorScreen>> screenKey,
  required Uri uri,
  required Object? error,
}) => Provider<Logger?>.value(
  value: logger,
  child: MaterialApp(
    home: RouteErrorScreen(
      key: screenKey,
      uri: uri,
      error: error,
    ),
  ),
);

final class _GoExceptionMimic implements Exception {
  _GoExceptionMimic(this.message);

  final String message;

  /// Intentionally matches [GoException.toString()] to prove the dedup key
  /// distinguishes error types, not just textual reasons.
  @override
  String toString() => 'GoException: $message';
}
