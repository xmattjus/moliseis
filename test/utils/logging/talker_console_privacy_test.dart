// Installed SDK integrations and scope access verify the actual print paths.
// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/breadcrumbs/debug_print_integration.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/recording_sentry_transport.dart';

void main() {
  for (final event in <LogEvent>[
    const SyncFailure(
      owner: SyncFailureOwner.prepare,
      category: SyncFailureCategory.contract,
    ),
    const CloudinaryRequestFailed(
      stage: CloudinaryFailureStage.upload,
      category: CloudinaryFailureCategory.http,
      statusCode: 400,
    ),
    const ContentSubmissionUploadFailed(),
    const AdminBackendRequestFailed(operation: 'associateStagedAsset'),
  ]) {
    for (final forwardingEnabled in [false, true]) {
      test('unfiltered Talker stays local ${event.name}, '
          'forwarding=$forwardingEnabled', () async {
        final originalDebugPrint = debugPrint;
        final originalPlatform = debugDefaultTargetPlatformOverride;
        addTearDown(() async {
          await Sentry.close();
          debugPrint = originalDebugPrint;
          debugDefaultTargetPlatformOverride = originalPlatform;
        });
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final transport = RecordingSentryTransport();
        final options = SentryFlutterOptions(checker: NonDebugRuntimeChecker())
          ..addIntegration(DebugPrintIntegration());
        final talker = TalkerFlutter.init();
        final logger = AppLogger(
          talker,
          sentryFlag: SentryLoggingFlag(initialValue: forwardingEnabled),
        );
        const canary = 'PRIVATE_LOCAL_CONSOLE';
        final error = Exception('$canary\ncontinuation');
        final stack = StackTrace.fromString('$canary\nstack continuation');
        await Sentry.init(
          (options) {
            options
              ..dsn = 'https://abc@example.test/1'
              ..automatedTestMode = true
              ..enablePrintBreadcrumbs = false
              ..transport = transport
              ..addEventProcessor(transport);
          },
          options: options,
          appRunner: () async {
            // Unframed output must also stay local.
            // ignore: avoid_print
            print(canary);
            debugPrint(canary);
            logger
              ..log(const SyncStarted(SyncMode.delta))
              ..log(
                event,
                error: error,
                stackTrace: stack,
                extra: const {'private': canary},
              );
          },
        );
        await debugPrintDone;
        await transport.settleCaptures();
        expect(options.beforeBreadcrumb, isNull);
        expect(options.enablePrintBreadcrumbs, isFalse);
        expect(debugPrint, same(originalDebugPrint));
        expect(talker.history.last.exception, same(error));
        expect(talker.history.last.stackTrace, same(stack));
        expect(transport.events, hasLength(forwardingEnabled ? 1 : 0));
        final breadcrumbs = Sentry.currentHub.scope.breadcrumbs;
        expect(breadcrumbs.where((b) => b.category == 'console'), isEmpty);
        expect(
          breadcrumbs.where((b) => b.message == 'content_sync_started'),
          hasLength(forwardingEnabled ? 1 : 0),
        );
        final followup = await Sentry.captureMessage('innocuous followup');
        await transport.settleCaptures();
        expect(
          transport.envelopes.any((e) => e.header.eventId == followup),
          isTrue,
        );
        for (var i = 0; i < transport.envelopes.length; i++) {
          expect(
            jsonEncode(await transport.serializedEvent(i)),
            isNot(contains(canary)),
          );
        }
      });
    }
  }

  test(
    'print interception off preserves automatic unhandled-error capture',
    () async {
      final transport = RecordingSentryTransport();
      final observed = Completer<Object>();
      final error = StateError('CONTROLLED_AUTOMATIC_ERROR');
      addTearDown(Sentry.close);
      await Sentry.init(
        (options) {
          options
            ..dsn = 'https://abc@example.test/1'
            ..automatedTestMode = true
            ..enablePrintBreadcrumbs = false
            ..transport = transport
            ..addEventProcessor(transport);
        },
        appRunner: () {
          scheduleMicrotask(() => throw error);
        },
        runZonedGuardedOnError: (caught, _) => observed.complete(caught),
      );
      expect(await observed.future, same(error));
      await transport.settleCaptures();
      expect(transport.envelopes, hasLength(1));
      final event = await transport.serializedEvent(0);
      expect(transport.exceptionValues(event).single['type'], 'StateError');
    },
  );
}
