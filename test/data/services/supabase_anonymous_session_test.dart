// Mocktail interception and verification APIs intentionally require closures;
// tear-offs cannot express the getter stubs used by these tests.
// ignore_for_file: unnecessary_lambdas

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/services/supabase_anonymous_session.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/mock_gotrue_client.dart';
import '../../support/mock_logger.dart';

void main() {
  group('ensureAnonymousSupabaseSession', () {
    test('reuses an existing user without signing in or logging', () async {
      final authClient = MockGoTrueClient();
      final logger = MockLogger();

      when(() => authClient.currentUser).thenReturn(MockUser());

      await ensureAnonymousSupabaseSession(
        authClient: authClient,
        logger: logger,
      );

      verifyNever(() => authClient.signInAnonymously());
      expect(logger.calls, isEmpty);
    });

    test('signs in once when there is no existing user', () async {
      final authClient = MockGoTrueClient();
      final logger = MockLogger();

      when(() => authClient.currentUser).thenReturn(null);
      when(
        () => authClient.signInAnonymously(),
      ).thenAnswer((_) async => MockAuthResponse());

      await ensureAnonymousSupabaseSession(
        authClient: authClient,
        logger: logger,
      );

      verify(() => authClient.signInAnonymously()).called(1);
      expect(logger.calls, isEmpty);
    });

    test(
      'handles and logs a retryable auth failure without retrying',
      () async {
        final authClient = MockGoTrueClient();
        final logger = MockLogger();
        final exception = AuthRetryableFetchException(
          message: 'Synthetic retryable auth failure',
        );

        when(() => authClient.currentUser).thenReturn(null);
        when(
          () => authClient.signInAnonymously(),
        ).thenThrow(exception);

        await expectLater(
          ensureAnonymousSupabaseSession(
            authClient: authClient,
            logger: logger,
          ),
          completes,
        );

        verify(() => authClient.signInAnonymously()).called(1);
        expect(
          logger.eventsOfType<SupabaseAuthAnonymousLoginFailed>(),
          hasLength(1),
        );
        expect(logger.calls, hasLength(1));

        final call = logger.firstCallOfType<SupabaseAuthAnonymousLoginFailed>();
        expect(call, isNotNull);
        expect(call!.error, same(exception));
        expect(call.stackTrace, isNotNull);
      },
    );

    test('handles and logs other auth failures without retrying', () async {
      final authClient = MockGoTrueClient();
      final logger = MockLogger();
      const exception = AuthException('Synthetic auth failure');

      when(() => authClient.currentUser).thenReturn(null);
      when(
        () => authClient.signInAnonymously(),
      ).thenThrow(exception);

      await expectLater(
        ensureAnonymousSupabaseSession(
          authClient: authClient,
          logger: logger,
        ),
        completes,
      );

      verify(() => authClient.signInAnonymously()).called(1);
      expect(
        logger.eventsOfType<SupabaseAuthAnonymousLoginFailed>(),
        hasLength(1),
      );

      final call = logger.firstCallOfType<SupabaseAuthAnonymousLoginFailed>();
      expect(call, isNotNull);
      expect(call!.error, same(exception));
      expect(call.stackTrace, isNotNull);
    });
  });
}
