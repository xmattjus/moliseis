// Sentry internals (currentHub, scope, automatedTestMode) are required
// for verifying breadcrumb and captureException behavior in tests.
// ignore_for_file: invalid_use_of_internal_member

// Mocktail matchers (any, captureAny) intentionally omit type arguments.
// ignore_for_file: inference_failure_on_function_invocation

// Test readability benefits from separate statements over cascades.
// ignore_for_file: cascade_invocations

import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show HttpExceptionWithStatus;
import 'package:command_it/command_it.dart' as commands;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/utils/command_configuration.dart';
import 'package:moliseis/utils/logging/app_log_level.dart';
import 'package:moliseis/utils/logging/app_logger.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/result.dart' show Result;
import 'package:moliseis/utils/result_command.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/recording_sentry_transport.dart';

class MockTalker extends Mock implements Talker {}

void main() {
  late MockTalker mockTalker;
  late SentryLoggingFlag sentryFlag;
  late RecordingSentryTransport fakeTransport;

  setUpAll(() {
    registerFallbackValue(LogLevel.debug);
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() async {
    mockTalker = MockTalker();
    sentryFlag = SentryLoggingFlag(initialValue: false);
    fakeTransport = RecordingSentryTransport();

    await Sentry.init((options) {
      options
        ..dsn = 'https://abc@def.ingest.sentry.io/1234'
        ..automatedTestMode = true
        ..transport = fakeTransport
        ..addEventProcessor(fakeTransport);
    });
    // Capture observation must survive the per-event privacy scope clear.
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

        logger.log(const SentryLoggingEnabled());

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

        logger.log(const ImageLoadFailed(url: 'test'));

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
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        logger.log(const SentryLoggingEnabled());

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
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        logger.log(const ImageLoadFailed(url: ''));

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
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);
        final error = Exception('test error');
        final stackTrace = StackTrace.current;

        logger.log(
          const ImageLoadFailed(url: ''),
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
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        logger.log(const RepositorySyncStarted('city'));

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
        expect(data, {'repositoryName': 'city'});
      });
    });

    group('data merging', () {
      test('forwards only event data when extra is null', () {
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

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
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

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
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

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
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        logger.log(const ImageLoadFailed(url: ''));

        await fakeTransport.settleCaptures();

        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, isEmpty);
      });

      test('does not capture exception when flag is disabled', () async {
        sentryFlag.enabled = false;
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        logger.log(
          const ImageLoadFailed(url: ''),
          error: Exception('should not be captured'),
        );

        await fakeTransport.settleCaptures();

        expect(fakeTransport.events, isEmpty);
        expect(fakeTransport.envelopes, isEmpty);
      });

      test('does not add breadcrumb for debug-level events', () async {
        sentryFlag.enabled = true;
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        logger.log(const SentryLoggingEnabled());

        await fakeTransport.settleCaptures();

        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, isEmpty);
      });

      test('adds breadcrumb for info-level events', () async {
        sentryFlag.enabled = true;
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        logger.log(const RepositorySyncStarted('city'));

        await fakeTransport.settleCaptures();

        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, hasLength(1));

        final breadcrumb = breadcrumbs.first;
        expect(breadcrumb.message, 'repository_sync_started');
        expect(breadcrumb.data, {'repositoryName': 'city'});
        expect(breadcrumb.level, SentryLevel.info);
        expect(breadcrumb.type, 'log');
        expect(breadcrumb.category, 'app');
      });

      test('adds breadcrumb for warning-level events', () async {
        sentryFlag.enabled = true;
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        logger.log(const NetworkRequestTimeout());

        await fakeTransport.settleCaptures();

        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, hasLength(1));
        expect(breadcrumbs.first.level, SentryLevel.warning);
      });

      test(
        'captures explicitly reportable persistence failure with cause',
        () async {
          sentryFlag.enabled = true;
          final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

          logger.log(
            const ContentSubmissionDraftLoadFailed(),
            error: Exception('captured'),
          );

          await fakeTransport.settleCaptures();

          expect(fakeTransport.envelopes, hasLength(1));
        },
      );

      test(
        'captures exception for critical-level with non-null error',
        () async {
          sentryFlag.enabled = true;
          final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

          logger.log(
            const LocalPersistenceInitFailed(),
            error: Exception('fatal'),
          );

          await fakeTransport.settleCaptures();

          expect(fakeTransport.envelopes, hasLength(1));
        },
      );

      test(
        'does not capture exception for error-level with null error',
        () async {
          sentryFlag.enabled = true;
          final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

          logger.log(const ImageLoadFailed(url: ''));

          await fakeTransport.settleCaptures();

          expect(fakeTransport.events, isEmpty);
          expect(fakeTransport.envelopes, isEmpty);
        },
      );

      test(
        'does not capture exception for warning-level even with error',
        () async {
          sentryFlag.enabled = true;
          final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

          logger.log(
            const NetworkRequestTimeout(),
            error: Exception('not captured'),
          );

          await fakeTransport.settleCaptures();

          expect(fakeTransport.events, isEmpty);
          expect(fakeTransport.envelopes, isEmpty);
        },
      );

      test('breadcrumb excludes local extra data', () async {
        sentryFlag.enabled = true;
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        logger.log(
          const RepositorySyncStarted('events'),
          extra: {'retries': 2},
        );

        await fakeTransport.settleCaptures();

        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, hasLength(1));
        expect(breadcrumbs.first.data, {'repositoryName': 'other'});
      });
    });

    for (final enabled in [false, true]) {
      test(
        'command failure respects runtime Sentry enabled=$enabled',
        () async {
          sentryFlag.enabled = enabled;
          final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);
          final error = StateError('command runtime failure');
          final stack = StackTrace.fromString('original command stack');

          logger.log(
            const CommandExecutionFailed(debugName: 'search_results'),
            error: error,
            stackTrace: stack,
          );
          await fakeTransport.settleCaptures();

          verify(
            () => mockTalker.log(
              {
                'command_execution_failed',
                {'debugName': 'search_results'},
              },
              logLevel: LogLevel.error,
              exception: error,
              stackTrace: stack,
            ),
          ).called(1);
          expect(fakeTransport.events, hasLength(enabled ? 1 : 0));
          expect(fakeTransport.envelopes, hasLength(enabled ? 1 : 0));
          expect(
            Sentry.currentHub.scope.breadcrumbs,
            hasLength(enabled ? 1 : 0),
          );
        },
      );
    }

    for (final event in <LogEvent>[
      const CloudinaryUploadCompleted(),
      const CloudinaryDuplicateDetected(
        source: CloudinaryReuseSource.preparation,
      ),
      const CloudinaryDuplicateDetected(source: CloudinaryReuseSource.response),
      const CloudinaryUploadCancelled(),
      const ContentSubmissionConfirmed(),
      const ContentSubmissionReplayAcknowledged(),
      const AdminStagedAssetAssociated(replayed: false),
      const AdminStagedAssetAssociated(replayed: true),
    ]) {
      test('${event.name} forwards only typed safe fields', () async {
        sentryFlag.enabled = true;
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);
        logger.log(event, extra: {'authorization': 'PRIVATE_AUTH_CANARY'});
        await fakeTransport.settleCaptures();
        expect(fakeTransport.events, isEmpty);
        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs, hasLength(1));
        expect(breadcrumbs.single.data, event.data);
        expect(
          jsonEncode(breadcrumbs.single.toJson()),
          isNot(contains('PRIVATE_AUTH_CANARY')),
        );
      });
    }

    test(
      'expected Cloudinary causes remain local with consent enabled',
      () async {
        sentryFlag.enabled = true;
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);
        for (final event in <LogEvent>[
          const CloudinaryRequestFailed(
            stage: CloudinaryFailureStage.preflight,
            category: CloudinaryFailureCategory.validation,
          ),
          const CloudinaryRequestFailed(
            stage: CloudinaryFailureStage.preflight,
            category: CloudinaryFailureCategory.fileRead,
          ),
          const CloudinaryUploadCancelled(),
          const CloudinaryUploadRetry(
            category: CloudinaryFailureCategory.timeout,
            attempt: 1,
          ),
        ]) {
          logger.log(event, error: Exception('PRIVATE_EXPECTED_CAUSE'));
        }
        await fakeTransport.settleCaptures();
        expect(fakeTransport.events, isEmpty);
        expect(fakeTransport.envelopes, isEmpty);
        expect(
          jsonEncode(
            Sentry.currentHub.scope.breadcrumbs
                .map((entry) => entry.toJson())
                .toList(),
          ),
          isNot(contains('PRIVATE_EXPECTED_CAUSE')),
        );
      },
    );

    for (final enabled in [false, true]) {
      for (final status in [400, 503]) {
        for (final event in <LogEvent>[
          CloudinaryRequestFailed(
            stage: CloudinaryFailureStage.response,
            category: CloudinaryFailureCategory.http,
            statusCode: status,
          ),
          const CloudinaryRequestFailed(
            stage: CloudinaryFailureStage.upload,
            category: CloudinaryFailureCategory.timeout,
          ),
          const CloudinaryRequestFailed(
            stage: CloudinaryFailureStage.response,
            category: CloudinaryFailureCategory.invalidResponse,
          ),
          ContentSubmissionUploadFailed(
            outcome: status == 400
                ? AssociationOutcome.rejected
                : AssociationOutcome.unconfirmed,
            statusCode: status,
          ),
          AdminBackendRequestFailed(
            operation: 'associateStagedAsset',
            outcome: status == 400
                ? AssociationOutcome.rejected
                : AssociationOutcome.unconfirmed,
            statusCode: status,
          ),
        ]) {
          test(
            '${event.name} HTTP $status structured capture consent=$enabled',
            () async {
              sentryFlag.enabled = enabled;
              await Sentry.configureScope((scope) async {
                await scope.setContexts('private', {
                  'payload': 'PRIVATE_CONTEXT_CANARY',
                });
                await scope.setUser(SentryUser(id: 'PRIVATE_USER_CANARY'));
                await scope.setTag('private', 'PRIVATE_TAG_CANARY');
                await scope.addBreadcrumb(
                  Breadcrumb(message: 'PRIVATE_BREADCRUMB_CANARY'),
                );
              });
              final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);
              logger.log(
                event,
                error: Exception('PRIVATE_EXCEPTION_CANARY'),
                stackTrace: StackTrace.fromString('PRIVATE_STACK_CANARY'),
                extra: {
                  'authorization': 'PRIVATE_EXTRA_CANARY',
                  'status_code': 201,
                },
              );
              await fakeTransport.settleCaptures();
              expect(fakeTransport.events, hasLength(enabled ? 1 : 0));
              expect(fakeTransport.envelopes, hasLength(enabled ? 1 : 0));
              if (enabled) {
                expect(
                  fakeTransport.events.single.contexts['upload_diagnostic'],
                  event.data,
                );
                final serialized = await utf8.decoder
                    .bind(
                      fakeTransport.envelopes.single.envelopeStream(
                        SentryOptions(),
                      ),
                    )
                    .join();
                // Check the serialized event, independent of breadcrumbs.
                final payload =
                    (jsonDecode(serialized.trim().split('\n').last)
                            as Map)['contexts']
                        as Map;
                expect(payload['upload_diagnostic'], event.data);
                expect(serialized, isNot(contains('PRIVATE_')));
              }
              expect(Sentry.currentHub.scope.contexts['private'], {
                'payload': 'PRIVATE_CONTEXT_CANARY',
              });
              expect(Sentry.currentHub.scope.user!.id, 'PRIVATE_USER_CANARY');
              // Later ordinary captures retain the global scope.
              await Sentry.captureMessage('subsequent ordinary capture');
              await fakeTransport.settleCaptures();
              final later = fakeTransport.events.last;
              expect(later.contexts['private'], {
                'payload': 'PRIVATE_CONTEXT_CANARY',
              });
              expect(later.user!.id, 'PRIVATE_USER_CANARY');
              expect(later.contexts['upload_diagnostic'], isNull);
            },
          );
        }
      }
    }

    test('scoped capture drops inherited private context', () async {
      sentryFlag.enabled = true;
      await Sentry.configureScope((scope) async {
        await scope.setContexts('private', {
          'payload': 'PRIVATE_CONTEXT_CANARY',
        });
        await scope.setUser(SentryUser(id: 'PRIVATE_ACCOUNT_CANARY'));
      });
      final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);
      logger.log(
        const ContentSubmissionUploadFailed(),
        error: Exception('PRIVATE_EXCEPTION_CANARY'),
        stackTrace: StackTrace.fromString('PRIVATE_STACK_CANARY'),
      );
      await fakeTransport.settleCaptures();
      expect(fakeTransport.events, hasLength(1));
      expect(fakeTransport.envelopes, hasLength(1));
      final serialized = await utf8.decoder
          .bind(fakeTransport.envelopes.single.envelopeStream(SentryOptions()))
          .join();
      expect(serialized, contains('unconfirmed'));
      expect(serialized, isNot(contains('PRIVATE_')));
    });

    for (final name in [
      'content_submission_submit',
      'admin_submission_editor_save',
      'admin_submission_editor_add_asset',
      'search_results',
    ]) {
      for (final error in [
        StateError('PRIVATE_FILE_ERROR'),
        const FileSystemException(
          'PRIVATE_FILE_ERROR',
          '/private/PRIVATE_FILE_PATH',
        ),
      ]) {
        test('global $name ${error.runtimeType} retains ownership '
            'and scopes causes', () async {
          final previousHandler = commands.Command.globalExceptionHandler;
          final previousReportAll = commands.Command.reportAllExceptions;
          addTearDown(() {
            commands.Command.globalExceptionHandler = previousHandler;
            commands.Command.reportAllExceptions = previousReportAll;
          });
          final command = createResultCommandNoParam<void>(
            () async => const Result.success(null),
            debugName: name,
          );
          addTearDown(command.dispose);
          sentryFlag.enabled = true;
          final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);
          configureCommandReporting(logger);
          final stack = StackTrace.fromString('PRIVATE_FILE_STACK');
          commands.Command.globalExceptionHandler!(
            commands.CommandError<void>(command: command, error: error),
            stack,
          );
          await fakeTransport.settleCaptures();
          final capture =
              error is! FileSystemException || name == 'search_results';
          expect(fakeTransport.events, hasLength(capture ? 1 : 0));
          expect(fakeTransport.envelopes, hasLength(capture ? 1 : 0));
          if (capture) {
            final payload = await utf8.decoder
                .bind(
                  fakeTransport.envelopes.single.envelopeStream(
                    SentryOptions(),
                  ),
                )
                .join();
            expect(payload, isNot(contains('PRIVATE_FILE_')));
          } else {
            expect(fakeTransport.events, isEmpty);
          }
          verify(
            () => mockTalker.log(
              any(),
              logLevel: LogLevel.error,
              exception: error,
              stackTrace: stack,
            ),
          ).called(1);
        });
      }
    }

    test('repeated handled image errors remain useful breadcrumbs '
        'without captures', () async {
      sentryFlag.enabled = true;
      final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);
      final error = HttpExceptionWithStatus(
        404,
        'PRIVATE_IMAGE_MESSAGE',
        uri: Uri.parse('https://private.invalid/PRIVATE_IMAGE_URL'),
      );
      for (var rebuild = 0; rebuild < 3; rebuild++) {
        logger.log(
          const ImageLoadFailed(url: 'PRIVATE_IMAGE_URL'),
          error: error,
        );
      }
      await fakeTransport.settleCaptures();
      expect(fakeTransport.events, isEmpty);
      expect(fakeTransport.envelopes, isEmpty);
      final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
      expect(breadcrumbs, hasLength(3));
      expect(breadcrumbs.last.data, {
        'cause_type': 'HttpExceptionWithStatus',
        'status_code': 404,
      });
      expect(
        jsonEncode(breadcrumbs.map((b) => b.toJson()).toList()),
        isNot(contains('PRIVATE_IMAGE')),
      );
    });

    group('event name assertion', () {
      test('valid three-segment name passes assertion', () {
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        // Should not throw.
        logger.log(const ImageLoadFailed(url: ''));
      });

      test('valid multi-segment name passes assertion', () {
        final logger = AppLogger(mockTalker, sentryFlag: sentryFlag);

        // 'content_submission_asset_removal_failed' has 5 segments.
        logger.log(const ContentSubmissionAssetRemovalFailed());
      });
    });
  });
}
