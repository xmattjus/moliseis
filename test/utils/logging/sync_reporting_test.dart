// Sentry test mode and scope inspection are needed for payload assertions.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;
import 'dart:io';

import 'package:command_it/command_it.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:moliseis/data/core/objectbox_sync_transaction_coordinator.dart';
import 'package:moliseis/data/core/supabase_sync_cursor_source.dart';
import 'package:moliseis/data/data-sources/settings_local_data_source.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/command_configuration.dart';
import 'package:moliseis/utils/logging/filter_breadcrumb.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
// Select Linux enrichment without replacing the SDK's real process I/O.
import 'package:sentry/src/platform/mock_platform.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/fake_repositories.dart';
import '../../support/mock_supabase.dart';
import '../../support/objectbox_test_store.dart';
import '../../support/recording_sentry_transport.dart';
import '../../support/sync_repository_test_support.dart';
import '../../support/sync_use_case_test_support.dart';

void main() {
  const secret =
      'PRIVATE_CANARY https://secret.invalid token=secret\nprivate-body';
  late RecordingSentryTransport transport;
  late Talker talker;
  late AppLogger logger;
  late SentryLoggingFlag consent;
  late List<String> console;

  setUpAll(setUpMockSupabase);
  setUp(() async {
    transport = RecordingSentryTransport();
    console = [];
    await Sentry.init((options) {
      options
        ..dsn = 'https://abc@def.ingest.sentry.io/1234'
        ..automatedTestMode = true
        ..platform = MockPlatform.linux()
        ..transport = transport
        ..addEventProcessor(transport)
        ..traceLifecycle = SentryTraceLifecycle.stream
        ..tracesSampleRate = 1.0
        ..beforeSendSpan = transport.recordSpan
        ..beforeBreadcrumb = filterBreadcrumb;
    });
    talker = Talker(
      logger: TalkerLogger(
        output: (message) {
          // The locked IO logger sends exactly these newline-split print calls.
          for (final line in message.split('\n')) {
            console.add(line);
            unawaited(
              Sentry.addBreadcrumb(
                Breadcrumb.console(message: line, level: SentryLevel.debug),
              ),
            );
          }
        },
      ),
    );
    await Sentry.configureScope((scope) async {
      await scope.setContexts('private', {'payload': secret});
    });
    consent = SentryLoggingFlag(initialValue: true);
    logger = AppLogger(talker, sentryFlag: consent);
  });
  tearDown(Sentry.close);

  for (final enabled in [false, true]) {
    for (final failure in <Exception>[
      TimeoutException(secret),
      const SocketException(secret),
      ClientException(secret),
      const FormatException(secret),
    ]) {
      for (final owner in [
        SyncFailureOwner.cursor,
        SyncFailureOwner.prepare,
        SyncFailureOwner.commit,
        SyncFailureOwner.settings,
      ]) {
        test('$owner ${failure.runtimeType} consent=$enabled', () async {
          consent.enabled = enabled;
          final stack = StackTrace.fromString(secret);
          switch (owner) {
            case SyncFailureOwner.cursor:
              final env = MockSupabaseEnvironment()
                ..stubRpcNetworkError(failure);
              final result = await SupabaseSyncCursorSource(
                env.client,
                logger: logger,
              ).getCurrentCursor();
              expect((result as Error<DateTime>).error, same(failure));
            case SyncFailureOwner.prepare:
              final repo = StubSyncRepository(logger)
                ..fetchError = failure
                ..fetchStackTrace = stack;
              final result = await repo.prepareSync();
              expect((result as Error<List<FakeSyncDto>>).error, same(failure));
            case SyncFailureOwner.commit:
              final env = await TestObjectBoxEnvironment.create();
              addTearDown(env.dispose);
              final result =
                  ObjectBoxSyncTransactionCoordinator(
                    env.store,
                    logger: logger,
                  ).runInWriteTransaction(() {
                    core.Error.throwWithStackTrace(failure, stack);
                  });
              expect((result as Error<void>).error, same(failure));
            case SyncFailureOwner.settings:
              final env = await TestObjectBoxEnvironment.create();
              addTearDown(env.dispose);
              final result =
                  await SettingsLocalDataSource(
                    env.store,
                    logger: logger,
                  ).update(
                    (_) => core.Error.throwWithStackTrace(failure, stack),
                    reportSyncFailure: true,
                  );
              expect((result as Error<void>).error, same(failure));
            case SyncFailureOwner.command:
              fail('Command covered through real ViewModel below');
          }
          // Terminal publication has no attached cause and cannot recapture.
          logger.log(
            const SyncFinished(
              mode: SyncMode.bootstrap,
              phase: SyncPhase.settings,
              succeeded: false,
              elapsedMs: 1,
            ),
          );
          await transport.settleCaptures();
          final expected = enabled && failure is FormatException ? 1 : 0;
          expect(transport.events, hasLength(expected));
          expect(transport.envelopes, hasLength(expected));
          expect(
            talker.history.where(
              (entry) => identical(entry.exception, failure),
            ),
            hasLength(1),
          );
          expect(console.join('\n'), contains('PRIVATE_CANARY'));
          for (final event in transport.events) {
            final payload = jsonEncode(event.toJson());
            expect(payload, isNot(contains('PRIVATE_CANARY')));
            expect(payload, isNot(contains('secret.invalid')));
            expect(event.exceptions!.single.type, 'CanonicalSyncFailure');
          }
          final accepted = Sentry.currentHub.scope.breadcrumbs;
          expect(
            jsonEncode(accepted.map((b) => b.toJson()).toList()),
            isNot(contains('PRIVATE_CANARY')),
          );
          expect(accepted.where((b) => b.category == 'console'), isEmpty);
        });
      }
    }
    for (final failure in <Object>[StateError(secret), secret]) {
      // Sentry's Linux enrichment starts real I/O before transport delivery.
      test(
        'real sync command ${failure.runtimeType} consent=$enabled',
        () async {
          consent.enabled = enabled;
          final previous = Command.globalExceptionHandler;
          final previousAll = Command.reportAllExceptions;
          addTearDown(() {
            Command.globalExceptionHandler = previous;
            Command.reportAllExceptions = previousAll;
          });
          configureCommandReporting(logger);
          final deps = buildSyncUseCase(
            settings: FakeSettingsRepository(),
            logger: logger,
          );
          deps.cityRepo.pendingPrepare = Completer();
          final vm = SyncViewModel(syncUseCase: deps.useCase);
          await pumpEventQueue(times: 4);
          final stack = StackTrace.fromString(secret);
          deps.cityRepo.pendingPrepare!.completeError(failure, stack);
          await pumpEventQueue(times: 4);
          expect(vm.sync.results.value.unexpectedError, same(failure));
          final cause = talker.history.singleWhere(
            (e) => identical(e.exception, failure),
          );
          expect(cause.stackTrace.toString(), contains('PRIVATE_CANARY'));
          expect(cause.stackTrace.toString(), contains('private-body'));
          expect(
            talker.history.where(
              (e) => e.message?.contains('content_sync_failed') ?? false,
            ),
            hasLength(1),
          );
          await transport.settleCaptures();
          await transport.settleSpans(1);
          await Sentry.close();
          expect(transport.events, hasLength(enabled ? 1 : 0));
          if (enabled) {
            expect(
              transport.events.single.exceptions!.single.type,
              'CanonicalSyncFailure',
            );
          }
          expect(
            jsonEncode(transport.events.map((e) => e.toJson()).toList()),
            isNot(contains('PRIVATE_CANARY')),
          );
          expect(
            jsonEncode(
              transport.spans
                  .map(
                    (e) => {
                      'name': e.name,
                      'attributes': e.attributes.map(
                        (key, value) => MapEntry(key, value.value),
                      ),
                    },
                  )
                  .toList(),
            ),
            isNot(contains('PRIVATE_CANARY')),
          );
          vm.dispose();
          await pumpEventQueue(times: 4);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
      );
    }
  }

  for (final category in <String?>[null, 'app', 'http', 'navigation']) {
    test(
      'preserves non-console decorated breadcrumb category=$category',
      () async {
        final breadcrumb = Breadcrumb(
          message: 'Explore │ Map ┌ └',
          category: category,
        );
        await Sentry.addBreadcrumb(breadcrumb);
        expect(Sentry.currentHub.scope.breadcrumbs.single, same(breadcrumb));
      },
    );
  }

  test('rejects console exception, stack and multiline Talker fragments', () {
    for (final message in [
      '│ Exception: $secret',
      '│ StackTrace: $secret',
      '┌ Header\n│ Exception: $secret\n│ StackTrace: $secret\n└',
    ]) {
      expect(
        filterBreadcrumb(Breadcrumb.console(message: message), Hint()),
        isNull,
      );
    }
  });

  test(
    'real Talker preserves original stack; safe console breadcrumb survives',
    () async {
      expect(
        filterBreadcrumb(Breadcrumb.console(message: '─\u001b['), Hint()),
        isNull,
      );
      final error = Exception(secret);
      final stack = StackTrace.fromString(secret);
      logger.log(
        SyncFailure(
          owner: SyncFailureOwner.command,
          category: syncFailureCategory(error),
        ),
        error: error,
        stackTrace: stack,
      );
      await Sentry.addBreadcrumb(Breadcrumb.console(message: 'safe console'));
      await transport.settleCaptures();
      expect(talker.history.single.exception, same(error));
      expect(talker.history.single.stackTrace, same(stack));
      expect(
        console.any((line) => line.contains('Exception:')),
        isTrue,
        reason: console.join('\n'),
      );
      expect(
        console.any((line) => line.contains('StackTrace:')),
        isTrue,
        reason: console.join('\n'),
      );
      final accepted = Sentry.currentHub.scope.breadcrumbs;
      expect(
        accepted.where((b) => b.category == 'console').single.message,
        'safe console',
      );
      expect(
        jsonEncode(accepted.map((b) => b.toJson()).toList()),
        isNot(contains('PRIVATE_CANARY')),
      );
    },
  );
}
