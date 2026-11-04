import 'dart:core' as core;
import 'dart:core';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/objectbox_sync_transaction_coordinator.dart';
import 'package:moliseis/data/data-sources/app_settings.dart';
import 'package:moliseis/domain/core/sync_transaction_coordinator.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

import '../../support/mock_logger.dart';
import '../../support/objectbox_test_store.dart';

void main() {
  group('ObjectBoxSyncTransactionCoordinator', () {
    late TestObjectBoxEnvironment env;
    late SyncTransactionCoordinator coordinator;
    late MockLogger logger;

    setUp(() async {
      env = await TestObjectBoxEnvironment.create();
      logger = MockLogger();
      coordinator = ObjectBoxSyncTransactionCoordinator(
        env.store,
        logger: logger,
      );
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
      final failure = Result<void>.error(error);
      final settingsBox = env.store.box<AppSettings>();
      final result = coordinator.runInWriteTransaction(() {
        settingsBox.put(AppSettings());
        return failure;
      });
      expect(result, same(failure));
      expect(logger.calls, isEmpty);
      expect(result.isError, isTrue);
      expect((result as Error<void>).error, same(error));
      expect(settingsBox.get(AppSettings.singletonId), isNull);
    });
    for (final error in <Object>[
      Exception('private exception'),
      StateError('private runtime Error'),
    ]) {
      test(
        'rolls back and preserves ${error.runtimeType} at conversion boundary',
        () {
          final box = env.store.box<AppSettings>();
          final stack = StackTrace.fromString('original transaction stack');
          final result = coordinator.runInWriteTransaction(() {
            box.put(AppSettings());
            core.Error.throwWithStackTrace(error, stack);
          });
          expect(result, isA<Error<void>>());
          if (error is Exception) {
            expect((result as Error<void>).error, same(error));
          }
          expect(box.get(AppSettings.singletonId), isNull);
          final call = logger.firstCallOfType<SyncFailure>()!;
          expect(call.error, same(error));
          expect(call.stackTrace.toString(), stack.toString());
          expect(logger.eventsOfType<SyncFailure>(), hasLength(1));
        },
      );
    }

    test(
      'native closed-store failure is reported once without callback execution',
      () {
        env.close();
        var called = false;
        final result = coordinator.runInWriteTransaction(() {
          called = true;
          return const Result.success(null);
        });
        expect(result.isError, isTrue);
        expect(called, isFalse);
        expect(logger.eventsOfType<SyncFailure>(), hasLength(1));
        expect(logger.firstCallOfType<SyncFailure>()!.error, isNotNull);
      },
    );

    test(
      'other thrown objects roll back and propagate unchanged without capture',
      () {
        final error = Object();
        final stack = StackTrace.fromString('custom object stack');
        final box = env.store.box<AppSettings>();
        expect(
          () => coordinator.runInWriteTransaction(() {
            box.put(AppSettings());
            core.Error.throwWithStackTrace(error, stack);
          }),
          throwsA(same(error)),
        );
        expect(box.get(AppSettings.singletonId), isNull);
        expect(logger.calls, isEmpty);
      },
    );
  });
}
