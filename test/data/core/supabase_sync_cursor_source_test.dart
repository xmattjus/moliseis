import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/supabase_sync_cursor_source.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/mock_logger.dart';
import '../../support/mock_supabase.dart';

void main() {
  setUpAll(setUpMockSupabase);

  test('scalar offset cursor becomes UTC with microsecond precision', () async {
    final env = MockSupabaseEnvironment()
      ..stubRpcResponse('2026-10-12T14:01:02.123456+02:00');
    final result = await SupabaseSyncCursorSource(
      env.client,
      logger: MockLogger(),
    ).getCurrentCursor();
    expect(result.getOrNull(), DateTime.utc(2026, 10, 12, 12, 1, 2, 123, 456));
    expect(result.getOrNull()!.isUtc, isTrue);
    expect(env.requests.single.path, '/rest/v1/rpc/get_content_sync_cursor');
    expect(env.requests.single.queryParameters, isEmpty);
  });

  for (final value in <Object?>[null, 123, 'not-a-timestamp', <String>[]]) {
    test('malformed scalar $value returns an error without fallback', () async {
      final env = MockSupabaseEnvironment()..stubRpcResponse(value);
      final logger = MockLogger();
      final result = await SupabaseSyncCursorSource(
        env.client,
        logger: logger,
      ).getCurrentCursor();
      expect(result, isA<Error<DateTime>>());
      final call = logger.firstCallOfType<SyncFailure>()!;
      expect(call.error, same((result as Error<DateTime>).error));
      expect(call.stackTrace, isNotNull);
      expect(logger.eventsOfType<SyncFailure>(), hasLength(1));
      expect(env.requests, hasLength(1));
    });
  }

  for (final code in ['42501', 'PGRST202']) {
    test('RPC $code failure is explicit without fallback', () async {
      final env = MockSupabaseEnvironment()
        ..stubRpcError(
          PostgrestException(message: 'RPC unavailable', code: code),
        );
      final result = await SupabaseSyncCursorSource(
        env.client,
        logger: MockLogger(),
      ).getCurrentCursor();
      expect(result, isA<Error<DateTime>>());
      expect((result as Error<DateTime>).error, isA<PostgrestException>());
      expect(env.requests, hasLength(1));
    });
  }

  test(
    'network exception becomes Result.error without another request',
    () async {
      final error = Exception('offline');
      final env = MockSupabaseEnvironment()..stubRpcNetworkError(error);
      final logger = MockLogger();
      final result = await SupabaseSyncCursorSource(
        env.client,
        logger: logger,
      ).getCurrentCursor();
      expect((result as Error<DateTime>).error, same(error));
      final call = logger.firstCallOfType<SyncFailure>()!;
      expect(call.error, same(error));
      expect(call.stackTrace, isNotNull);
      expect(env.requests, hasLength(1));
    },
  );
}
