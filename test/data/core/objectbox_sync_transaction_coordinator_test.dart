import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/objectbox_sync_transaction_coordinator.dart';
import 'package:moliseis/domain/core/sync_transaction_coordinator.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/objectbox_test_store.dart';

void main() {
  group('ObjectBoxSyncTransactionCoordinator', () {
    late TestObjectBoxEnvironment env;
    late SyncTransactionCoordinator coordinator;

    setUp(() async {
      env = await TestObjectBoxEnvironment.create();
      coordinator = ObjectBoxSyncTransactionCoordinator(env.store);
    });

    tearDown(() async {
      await env.dispose();
    });

    test('runs the callback inside a write transaction', () {
      var called = false;
      final result = coordinator.runInWriteTransaction(() {
        called = true;
        return const Result.success(null);
      });
      expect(called, isTrue);
      expect(result.isSuccess, isTrue);
    });

    test('returns Result.error when the callback returns an error', () {
      final error = Exception('test error');
      final result = coordinator.runInWriteTransaction(() {
        return Result.error(error);
      });
      expect(result.isError, isTrue);
      expect((result as Error<void>).error, same(error));
    });
  });
}
