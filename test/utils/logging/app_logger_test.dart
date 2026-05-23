// Sentry internals (currentHub, scope, automatedTestMode) are required
// for verifying breadcrumb and captureException behavior in tests.
// ignore_for_file: invalid_use_of_internal_member

// Mocktail matchers (any, captureAny) intentionally omit type arguments.
// ignore_for_file: inference_failure_on_function_invocation

// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/utils/logging/app_log_level.dart';
import 'package:moliseis/utils/logging/app_logger.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

class MockTalker extends Mock implements Talker {}

/// A minimal [Transport] that records envelopes for test assertions.
class FakeTransport implements Transport {
  final List<SentryEnvelope> envelopes = [];

  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return envelope.header.eventId ?? SentryId.newId();
  }
}

void main() {
  late MockTalker mockTalker;
  late SentryLoggingFlag sentryFlag;
  late FakeTransport fakeTransport;

  setUpAll(() {
    registerFallbackValue(LogLevel.debug);
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() async {
    mockTalker = MockTalker();
    sentryFlag = SentryLoggingFlag(initialValue: false);
    fakeTransport = FakeTransport();

    await Sentry.init(
      (options) {
        options
          ..dsn = 'https://abc@def.ingest.sentry.io/1234'
          ..automatedTestMode = true
          ..transport = fakeTransport;
      },
    );
  });

  tearDown(() async {
    await Sentry.close();
  });

  group('AppLogger', () {
    // Real LogEvent subclasses used since LogEvent is sealed:
    // - SentryLoggingEnabled: debug
    // - RepositorySyncStarted: info
    // - NetworkRequestTimeout: warning
    // - ImageLoadFailed: error
    // - LocalPersistenceInitFailed: critical

    group('level filtering', () {
      test('suppresses events below minLevel', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
          minLevel: AppLogLevel.warning,
        );

        // Info is below warning.
        logger.log(const RepositorySyncStarted('test'));

        verifyNever(
          () => mockTalker.log(
            any(),
            logLevel: any(named: 'logLevel'),
            exception: any(named: 'exception'),
            stackTrace: any(named: 'stackTrace'),
          ),
        );
      });

      test('suppresses debug when minLevel is info', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
          minLevel: AppLogLevel.info,
        );

        logger.log(SentryLoggingEnabled());

        verifyNever(
          () => mockTalker.log(
            any(),
            logLevel: any(named: 'logLevel'),
            exception: any(named: 'exception'),
            stackTrace: any(named: 'stackTrace'),
          ),
        );
      });

      test('logs events at exactly minLevel', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
          minLevel: AppLogLevel.warning,
        );

        logger.log(const NetworkRequestTimeout());

        verify(
          () => mockTalker.log(
            any(),
            logLevel: any(named: 'logLevel'),
            exception: any(named: 'exception'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('logs events above minLevel', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
          minLevel: AppLogLevel.warning,
        );

        logger.log(const ImageLoadFailed());

        verify(
          () => mockTalker.log(
            any(),
            logLevel: any(named: 'logLevel'),
            exception: any(named: 'exception'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('default minLevel is debug (logs everything)', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(SentryLoggingEnabled());

        verify(
          () => mockTalker.log(
            any(),
            logLevel: any(named: 'logLevel'),
            exception: any(named: 'exception'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });
    });

    group('Talker output', () {
      test('passes mapped log level to Talker', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(const ImageLoadFailed());

        verify(
          () => mockTalker.log(
            any(),
            logLevel: LogLevel.error,
            exception: any(named: 'exception'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('passes error and stackTrace to Talker', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );
        final error = Exception('test error');
        final stackTrace = StackTrace.current;

        logger.log(
          const ImageLoadFailed(),
          error: error,
          stackTrace: stackTrace,
        );

        verify(
          () => mockTalker.log(
            any(),
            logLevel: any(named: 'logLevel'),
            exception: error,
            stackTrace: stackTrace,
          ),
        ).called(1);
      });

      test('passes event name and merged data as message set', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(const RepositorySyncStarted('cities'));

        final captured = verify(
          () => mockTalker.log(
            captureAny(),
            logLevel: any(named: 'logLevel'),
            exception: any(named: 'exception'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).captured;

        final message = captured.first as Set;
        expect(message, contains('repository_sync_started'));

        final data = message.whereType<Map<String, Object?>>().first;
        expect(data, {'repositoryName': 'cities'});
      });
    });

    group('data merging', () {
      test('forwards only event data when extra is null', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(const RepositorySyncStarted('places'));

        final captured = verify(
          () => mockTalker.log(
            captureAny(),
            logLevel: any(named: 'logLevel'),
            exception: any(named: 'exception'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).captured;

        final message = captured.first as Set;
        final data = message.whereType<Map<String, Object?>>().first;
        expect(data, {'repositoryName': 'places'});
      });

      test('merges extra data into event data', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(
          const RepositorySyncStarted('places'),
          extra: {'attempt': 3},
        );

        final captured = verify(
          () => mockTalker.log(
            captureAny(),
            logLevel: any(named: 'logLevel'),
            exception: any(named: 'exception'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).captured;

        final message = captured.first as Set;
        final data = message.whereType<Map<String, Object?>>().first;
        expect(data, {'repositoryName': 'places', 'attempt': 3});
      });

      test('extra overrides event data on key collision', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(
          const RepositorySyncStarted('places'),
          extra: {'repositoryName': 'overridden'},
        );

        final captured = verify(
          () => mockTalker.log(
            captureAny(),
            logLevel: any(named: 'logLevel'),
            exception: any(named: 'exception'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).captured;

        final message = captured.first as Set;
        final data = message.whereType<Map<String, Object?>>().first;
        expect(data, {'repositoryName': 'overridden'});
      });
    });

    group('Sentry integration', () {
      test('does not add breadcrumb when flag is disabled', () async {
        sentryFlag.enabled = false;
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(const ImageLoadFailed());

        // Allow microtask queue to flush.
        await Future<void>.delayed(Duration.zero);

        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, isEmpty);
      });

      test(
        'does not capture exception when flag is disabled',
        () async {
          sentryFlag.enabled = false;
          final logger = AppLogger(
            mockTalker,
            sentryFlag: sentryFlag,
          );

          logger.log(
            const ImageLoadFailed(),
            error: Exception('should not be captured'),
          );

          // Allow microtask queue to flush.
          await Future<void>.delayed(Duration.zero);

          expect(fakeTransport.envelopes, isEmpty);
        },
      );

      test('does not add breadcrumb for debug-level events', () async {
        sentryFlag.enabled = true;
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(SentryLoggingEnabled());

        // Allow microtask queue to flush.
        await Future<void>.delayed(Duration.zero);

        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, isEmpty);
      });

      test('adds breadcrumb for info-level events', () async {
        sentryFlag.enabled = true;
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(const RepositorySyncStarted('cities'));

        // Allow microtask queue to flush.
        await Future<void>.delayed(Duration.zero);

        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, hasLength(1));

        final breadcrumb = breadcrumbs.first;
        expect(breadcrumb.message, 'repository_sync_started');
        expect(breadcrumb.data, {'repositoryName': 'cities'});
        expect(breadcrumb.level, SentryLevel.info);
        expect(breadcrumb.type, 'log');
        expect(breadcrumb.category, 'app');
      });

      test('adds breadcrumb for warning-level events', () async {
        sentryFlag.enabled = true;
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(const NetworkRequestTimeout());

        // Allow microtask queue to flush.
        await Future<void>.delayed(Duration.zero);

        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, hasLength(1));
        expect(breadcrumbs.first.level, SentryLevel.warning);
      });

      test(
        'captures exception for error-level with non-null error',
        () async {
          sentryFlag.enabled = true;
          final logger = AppLogger(
            mockTalker,
            sentryFlag: sentryFlag,
          );

          logger.log(
            const ImageLoadFailed(),
            error: Exception('captured'),
          );

          // Allow microtask queue to flush.
          await Future<void>.delayed(Duration.zero);

          expect(fakeTransport.envelopes, hasLength(1));
        },
      );

      test(
        'captures exception for critical-level with non-null error',
        () async {
          sentryFlag.enabled = true;
          final logger = AppLogger(
            mockTalker,
            sentryFlag: sentryFlag,
          );

          logger.log(
            const LocalPersistenceInitFailed(),
            error: Exception('fatal'),
          );

          // Allow microtask queue to flush.
          await Future<void>.delayed(Duration.zero);

          expect(fakeTransport.envelopes, hasLength(1));
        },
      );

      test(
        'does not capture exception for error-level with null error',
        () async {
          sentryFlag.enabled = true;
          final logger = AppLogger(
            mockTalker,
            sentryFlag: sentryFlag,
          );

          logger.log(const ImageLoadFailed());

          // Allow microtask queue to flush.
          await Future<void>.delayed(Duration.zero);

          expect(fakeTransport.envelopes, isEmpty);
        },
      );

      test(
        'does not capture exception for warning-level even with error',
        () async {
          sentryFlag.enabled = true;
          final logger = AppLogger(
            mockTalker,
            sentryFlag: sentryFlag,
          );

          logger.log(
            const NetworkRequestTimeout(),
            error: Exception('not captured'),
          );

          // Allow microtask queue to flush.
          await Future<void>.delayed(Duration.zero);

          expect(fakeTransport.envelopes, isEmpty);
        },
      );

      test('breadcrumb includes merged extra data', () async {
        sentryFlag.enabled = true;
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        logger.log(
          const RepositorySyncStarted('events'),
          extra: {'retries': 2},
        );

        // Allow microtask queue to flush.
        await Future<void>.delayed(Duration.zero);

        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, hasLength(1));
        expect(
          breadcrumbs.first.data,
          {'repositoryName': 'events', 'retries': 2},
        );
      });
    });

    group('event name assertion', () {
      test('valid three-segment name passes assertion', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        // Should not throw.
        logger.log(const ImageLoadFailed());
      });

      test('valid multi-segment name passes assertion', () {
        final logger = AppLogger(
          mockTalker,
          sentryFlag: sentryFlag,
        );

        // 'user_contribution_media_removal_failed' has 5 segments.
        logger.log(const UserContributionMediaRemovalFailed());
      });
    });
  });
}
