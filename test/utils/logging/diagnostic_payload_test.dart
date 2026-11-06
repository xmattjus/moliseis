// Serialized Sentry envelopes are the observable privacy/reporting boundary.
// ignore_for_file: invalid_use_of_internal_member
// JSON payload assertions are intentionally dynamic; event calls stay linear.
// ignore_for_file: avoid_dynamic_calls, cascade_invocations
// Breadcrumb JSON is decoded as a heterogeneous SDK payload.
// ignore_for_file: inference_failure_on_untyped_parameter,
// ignore_for_file: prefer_const_constructors

import 'dart:convert';

import 'package:command_it/command_it.dart' as command_it;
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/command_configuration.dart';
import 'package:moliseis/utils/logging/app_logger.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/recording_sentry_transport.dart';

void main() {
  const privateCanary = 'PRIVATE_DIAGNOSTIC_CANARY';
  late RecordingSentryTransport transport;
  late Talker talker;
  late AppLogger logger;

  setUp(() async {
    transport = RecordingSentryTransport();
    talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
    await Sentry.init((options) {
      options
        ..dsn = 'https://abc@def.ingest.sentry.io/1234'
        ..automatedTestMode = true
        ..transport = transport
        ..addEventProcessor(transport);
    });
    await Sentry.configureScope((scope) async {
      await scope.setContexts('private', {'payload': privateCanary});
      await scope.setUser(SentryUser(id: privateCanary));
      await scope.setTag('private', privateCanary);
      await scope.addBreadcrumb(
        Breadcrumb(message: privateCanary, category: 'private'),
      );
    });
    logger = AppLogger(
      talker,
      sentryFlag: SentryLoggingFlag(initialValue: true),
    );
  });

  tearDown(Sentry.close);

  test(
    'sync reports distinguish repositories and retain commit context',
    () async {
      final cityError = FormatException(privateCanary);
      final mediaError = FormatException(privateCanary);
      final cityStack = StackTrace.fromString('$privateCanary city stack');
      final mediaStack = StackTrace.fromString('$privateCanary media stack');

      logger.log(const SyncStarted(SyncMode.delta));
      logger.log(const RepositorySyncStarted('city'));
      logger.log(
        const SyncFailure(
          owner: SyncFailureOwner.prepare,
          category: SyncFailureCategory.contract,
          repository: 'city',
        ),
        error: cityError,
        stackTrace: cityStack,
      );
      await transport.settleCaptures();

      logger.log(const SyncStarted(SyncMode.delta));
      logger.log(const RepositorySyncStarted('media'));
      logger.log(
        const SyncFailure(
          owner: SyncFailureOwner.prepare,
          category: SyncFailureCategory.contract,
          repository: 'media',
        ),
        error: mediaError,
        stackTrace: mediaStack,
      );
      await transport.settleCaptures();

      final cityEvent = await transport.serializedEvent(0);
      final mediaEvent = await transport.serializedEvent(1);
      final cityDiagnostic = cityEvent['contexts']['app_diagnostic'];
      final mediaDiagnostic = mediaEvent['contexts']['app_diagnostic'];
      expect(cityDiagnostic['owner'], 'prepare');
      expect(mediaDiagnostic['owner'], 'prepare');
      expect(cityDiagnostic['category'], 'contract');
      expect(mediaDiagnostic['category'], 'contract');
      expect(cityDiagnostic['repository'], 'city');
      expect(mediaDiagnostic['repository'], 'media');
      expect(cityDiagnostic['cause_type'], 'FormatException');
      expect(mediaDiagnostic['cause_type'], 'FormatException');
      expect(
        transport.exceptionValues(cityEvent).single['value'],
        isNot(transport.exceptionValues(mediaEvent).single['value']),
      );
      expect(cityEvent['breadcrumbs'].map((b) => b['message']), [
        'content_sync_started',
        'repository_sync_started',
        'content_sync_cause_failed',
      ]);
      expect(mediaEvent['breadcrumbs'].map((b) => b['message']), [
        'content_sync_started',
        'repository_sync_started',
        'content_sync_cause_failed',
      ]);

      // Preserve current-run context without adding waits between the start,
      // durable commit, and subsequent settings failure.
      logger.log(const SyncStarted(SyncMode.bootstrap));
      logger.log(const SyncContentCommitSucceeded());
      logger.log(
        const SyncFailure(
          owner: SyncFailureOwner.settings,
          category: SyncFailureCategory.storage,
          repository: 'city',
        ),
        error: cityError,
        stackTrace: cityStack,
      );
      await transport.settleCaptures();
      final settingsEvent = await transport.serializedEvent(2);
      expect(settingsEvent['contexts']['app_diagnostic']['owner'], 'settings');
      expect(settingsEvent['breadcrumbs'].map((b) => b['message']), [
        'content_sync_started',
        'content_commit_succeeded',
        'content_sync_cause_failed',
      ]);
      expect(
        jsonEncode([cityEvent, mediaEvent, settingsEvent]),
        isNot(contains(privateCanary)),
      );

      final localFailures = talker.history
          .where((entry) => entry.exception is FormatException)
          .toList();
      expect(localFailures, hasLength(3));
      expect(localFailures[0].exception, same(cityError));
      expect(localFailures[0].stackTrace, same(cityStack));
      expect(localFailures[1].exception, same(mediaError));
      expect(localFailures[1].stackTrace, same(mediaStack));
    },
  );

  test(
    'sync reports retain origin context for cause-less and thrown failures',
    () async {
      final unexpected = StateError(privateCanary);
      final unexpectedStack = StackTrace.fromString(
        '$privateCanary command stack',
      );
      final previousHandler = command_it.Command.globalExceptionHandler;
      final previousReportAll = command_it.Command.reportAllExceptions;
      addTearDown(() {
        command_it.Command.globalExceptionHandler = previousHandler;
        command_it.Command.reportAllExceptions = previousReportAll;
      });
      logger.log(const SyncStarted(SyncMode.bootstrap));
      logger.log(const RepositorySyncStarted('city'));
      logger.log(
        const SyncFailure(
          owner: SyncFailureOwner.command,
          category: SyncFailureCategory.unexpected,
        ),
      );
      await transport.settleCaptures();

      configureCommandReporting(logger);
      logger.log(const SyncStarted(SyncMode.delta));
      logger.log(const RepositorySyncStarted('media'));
      logger.log(
        const SyncFinished(
          mode: SyncMode.delta,
          phase: SyncPhase.prepare_media,
          succeeded: false,
          elapsedMs: 4,
          category: SyncFailureCategory.unexpected,
        ),
      );
      final command = createResultCommandNoParam<void>(
        () async => const Result.success(null),
        debugName: 'sync_view_model.sync',
      );
      addTearDown(command.dispose);
      command_it.Command.globalExceptionHandler!(
        command_it.CommandError<void>(command: command, error: unexpected),
        unexpectedStack,
      );
      await transport.settleCaptures();

      expect(transport.events, hasLength(2));
      final event = await transport.serializedEvent(0);
      expect(
        transport.exceptionValues(event).single['type'],
        'CanonicalSyncFailure',
      );
      expect(
        transport.exceptionValues(event).single['value'],
        contains('NoAttachedCause'),
      );
      expect(
        event['contexts']['app_diagnostic']['cause_type'],
        'NoAttachedCause',
      );
      expect(event['breadcrumbs'].map((b) => b['message']), [
        'content_sync_started',
        'repository_sync_started',
        'content_sync_cause_failed',
      ]);
      expect(jsonEncode(event), isNot(contains(privateCanary)));
      final unexpectedEvent = await transport.serializedEvent(1);
      expect(
        transport.exceptionValues(unexpectedEvent).single['type'],
        'CanonicalSyncFailure',
      );
      expect(
        unexpectedEvent['contexts']['app_diagnostic']['category'],
        'unexpected',
      );
      expect(unexpectedEvent['breadcrumbs'].map((b) => b['message']), [
        'content_sync_started',
        'repository_sync_started',
        'content_sync_failed',
        'content_sync_cause_failed',
      ]);
      expect(
        unexpectedEvent['breadcrumbs'][1]['data']['repositoryName'],
        'media',
      );
      expect(unexpectedEvent['breadcrumbs'][2]['data'], {
        'mode': 'delta',
        'phase': 'prepare_media',
        'category': 'unexpected',
      });
      expect(jsonEncode(unexpectedEvent), isNot(contains(privateCanary)));
      final local = talker.history.singleWhere(
        (entry) => identical(entry.exception, unexpected),
      );
      expect(local.stackTrace, same(unexpectedStack));
    },
  );

  test(
    'upload reports retain status and outcome without exception contents',
    () async {
      logger.log(
        const CloudinaryRequestFailed(
          stage: CloudinaryFailureStage.preparation,
          category: CloudinaryFailureCategory.preparation,
        ),
        error: FunctionException(
          status: 502,
          details: {'response': privateCanary},
          reasonPhrase: privateCanary,
        ),
      );
      logger.log(
        const ContentSubmissionUploadFailed(
          outcome: AssociationOutcome.rejected,
          statusCode: 422,
        ),
        error: Exception(privateCanary),
      );
      logger.log(
        const AdminBackendRequestFailed(
          operation: 'associateStagedAsset',
          outcome: AssociationOutcome.unconfirmed,
          statusCode: 503,
        ),
        error: Exception(privateCanary),
      );
      await transport.settleCaptures();

      expect(transport.events, hasLength(3));
      final events = <Map<String, dynamic>>[];
      for (final envelope in transport.envelopes) {
        events.add(
          await transport.serializedEvent(
            transport.envelopes.indexOf(envelope),
          ),
        );
      }
      expect(
        events[0]['contexts']['app_diagnostic'],
        containsPair('stage', 'preparation'),
      );
      expect(
        events[0]['contexts']['app_diagnostic'],
        containsPair('status_code', 502),
      );
      expect(
        events[0]['contexts']['app_diagnostic'],
        containsPair('cause_type', 'FunctionException'),
      );
      expect(
        events[1]['contexts']['app_diagnostic'],
        containsPair('outcome', 'rejected'),
      );
      expect(
        events[1]['contexts']['app_diagnostic'],
        containsPair('status_code', 422),
      );
      expect(
        events[2]['contexts']['app_diagnostic'],
        containsPair('outcome', 'unconfirmed'),
      );
      expect(
        events[2]['contexts']['app_diagnostic'],
        containsPair('status_code', 503),
      );
      expect(jsonEncode(events), isNot(contains(privateCanary)));
    },
  );

  test(
    'generic route failure reports known type without private details',
    () async {
      final error = FormatException(privateCanary);
      final stack = StackTrace.fromString(privateCanary);
      logger.log(
        const RouteErrorScreenShown(
          uri: '/private/$privateCanary',
          reason: privateCanary,
        ),
        error: error,
        stackTrace: stack,
        extra: const {'diagnostic': privateCanary},
      );
      await transport.settleCaptures();

      expect(transport.events, hasLength(1));
      final event = await transport.serializedEvent(0);
      expect(
        transport.exceptionValues(event).single['type'],
        'ApplicationFailure',
      );
      expect(
        event['contexts']['app_diagnostic']['event'],
        'route_error_screen_shown',
      );
      expect(
        event['contexts']['app_diagnostic']['cause_type'],
        'FormatException',
      );
      expect(jsonEncode(event), isNot(contains(privateCanary)));
      expect(jsonEncode(event), isNot(contains('/private/')));
      expect(talker.history.single.exception, same(error));
      expect(talker.history.single.stackTrace, same(stack));
    },
  );
}
