// SDK options expose deterministic diagnostic fault injection.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:core';
import 'dart:core' as core;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/logging_faults.dart';
import '../../support/recording_sentry_transport.dart';
import '../../support/sync_repository_test_support.dart';

void main() {
  late RecordingSentryTransport transport;
  late SentryOptions options;
  late Talker talker;
  late AppLogger logger;
  setUp(() async {
    transport = RecordingSentryTransport();
    await Sentry.init((o) {
      options = o;
      o
        ..dsn = 'https://abc@example.test/1'
        ..automatedTestMode = true
        ..transport = transport
        ..addEventProcessor(transport);
    });
    talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
    logger = AppLogger(
      talker,
      sentryFlag: SentryLoggingFlag(initialValue: true),
    );
  });
  tearDown(Sentry.close);

  test(
    'metadata failure retains original local cause and independent report',
    () async {
      final error = Exception('business');
      final stack = StackTrace.current;
      logger.log(
        const FaultyRepositoryEvent(failData: true),
        error: error,
        stackTrace: stack,
      );
      await transport.settleCaptures();
      expect(talker.history.single.exception, same(error));
      expect(talker.history.single.stackTrace, same(stack));
      expect(transport.envelopes, hasLength(1));
    },
  );

  test('unreadable filtering/name accessors do not escape', () {
    for (final event in [
      const FaultyRepositoryEvent(failLevel: true),
      const FaultyRepositoryEvent(failName: true),
    ]) {
      expect(() => logger.log(event), returnsNormally);
    }
  });

  test('Talker failure cannot suppress eligible remote report', () async {
    final brokenTalker = Talker(
      logger: TalkerLogger(output: (_) => throw StateError('sink')),
    );
    final logger = AppLogger(
      brokenTalker,
      sentryFlag: SentryLoggingFlag(initialValue: true),
    );
    expect(
      () => logger.log(
        const ContentSubmissionDraftLoadFailed(),
        error: Exception('business'),
      ),
      returnsNormally,
    );
    await transport.settleCaptures();
    expect(transport.envelopes, hasLength(1));
  });

  test(
    'synchronously throwing SDK breadcrumb hook does not suppress capture',
    () async {
      options.beforeBreadcrumb = (_, _) => throw StateError('SDK hook');
      expect(
        () => logger.log(
          const ContentSubmissionDraftLoadFailed(),
          error: Exception('business'),
        ),
        returnsNormally,
      );
      await transport.settleCaptures();
      expect(talker.history, hasLength(1));
      expect(transport.envelopes, hasLength(1));
    },
  );

  for (final automated in [false, true]) {
    test(
      'async capture processor failure is contained, test mode=$automated',
      () async {
        final invoked = Completer<void>();
        options
          ..automatedTestMode = automated
          ..beforeSend = (_, _) async {
            invoked.complete();
            throw StateError('remote completion');
          };
        logger.log(
          const ContentSubmissionDraftLoadFailed(),
          error: Exception('business'),
        );
        await invoked.future.timeout(const Duration(seconds: 5));
        await Future<void>(() {});
        expect(talker.history, hasLength(1));
        expect(transport.envelopes, isEmpty);
      },
    );
  }

  test('late native observer Future failure is consumed', () async {
    final observer = FailingBreadcrumbObserver();
    options.addScopeObserver(observer);
    logger.log(const NetworkRequestTimeout());
    observer.completion.completeError(StateError('native observer'));
    await Future<void>(() {});
    expect(talker.history, hasLength(1));
    expect(transport.events, isEmpty);
    options.scopeObservers.remove(observer);
  });

  test(
    'diagnostic faults preserve repository business Result identity',
    () async {
      options.beforeSend = (_, _) async => throw StateError('remote');
      final brokenTalker = Talker(
        logger: TalkerLogger(output: (_) => throw StateError('local')),
      );
      final logger = AppLogger(
        brokenTalker,
        sentryFlag: SentryLoggingFlag(initialValue: true),
      );
      final original = Exception('original business failure');
      final repo = StubSyncRepository(logger)..fetchError = original;
      final result = await repo.prepareSync();
      expect((result as Error<List<FakeSyncDto>>).error, same(original));
      await Future<void>(() {});
    },
  );

  test('diagnostic faults preserve original raw throw and stack', () async {
    final brokenTalker = Talker(
      logger: TalkerLogger(output: (_) => throw StateError('local')),
    );
    final logger = AppLogger(
      brokenTalker,
      sentryFlag: SentryLoggingFlag(initialValue: true),
    );
    final original = StateError('original business throw');
    final stack = StackTrace.fromString('original stack');
    final repo = StubSyncRepository(logger)
      ..fetchError = original
      ..fetchStackTrace = stack;
    try {
      await repo.prepareSync();
      fail('Expected original throw');
      // The original business Error must survive diagnostic faults unchanged.
      // ignore: avoid_catching_errors
    } on core.Error catch (error, caughtStack) {
      expect(error, same(original));
      expect(caughtStack.toString(), stack.toString());
    }
  });
}
