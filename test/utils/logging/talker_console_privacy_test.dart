// SDK options and scope access verify the installed interception end to end.
// ignore_for_file: invalid_use_of_internal_member

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/filter_breadcrumb.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// The locked Flutter integration is not exported by sentry_flutter.dart.
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
      test(
        'real Talker privacy ${event.name}, forwarding=$forwardingEnabled',
        () async {
          final originalDebugPrint = debugPrint;
          final originalPlatform = debugDefaultTargetPlatformOverride;
          addTearDown(() async {
            try {
              await Sentry.close();
              expect(debugPrint, same(originalDebugPrint));
            } finally {
              debugPrint = originalDebugPrint;
              debugDefaultTargetPlatformOverride = originalPlatform;
            }
          });
          // Select the Dart debugPrint path, without a native build.
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          final transport = RecordingSentryTransport();
          final observedConsole = <String>[];
          final options = SentryFlutterOptions(
            checker: NonDebugRuntimeChecker(),
          )..addIntegration(DebugPrintIntegration());
          await Sentry.init((options) {
            options
              ..dsn = 'https://abc@example.test/1'
              ..automatedTestMode = true
              ..enablePrintBreadcrumbs = false
              ..transport = transport
              ..addEventProcessor(transport)
              ..beforeBreadcrumb = (breadcrumb, hint) {
                if (breadcrumb?.category == 'console') {
                  observedConsole.add(breadcrumb?.message ?? '');
                }
                return filterBreadcrumb(breadcrumb, hint);
              };
          }, options: options);
          expect(options.runtimeChecker.isDebugMode(), isFalse);
          expect(options.enablePrintBreadcrumbs, isFalse);
          expect(debugPrint, same(originalDebugPrint));

          const safeConsole = 'TASK41_SAFE_CONSOLE';
          const followupMessage = 'TASK41_INNOCUOUS_FOLLOWUP';
          const exceptionCanary = 'TASK41_PRIVATE_EXCEPTION_CANARY';
          const stackCanary = 'TASK41_PRIVATE_STACK_CANARY';
          debugPrint(safeConsole);
          final talker = TalkerFlutter.init();
          final logger = AppLogger(
            talker,
            sentryFlag: SentryLoggingFlag(initialValue: forwardingEnabled),
          );
          final error = Exception(
            '$exceptionCanary\nprivate exception continuation',
          );
          final stack = StackTrace.fromString(
            '$stackCanary\nprivate stack continuation',
          );
          logger.log(
            event,
            error: error,
            stackTrace: stack,
            extra: const {
              'submission_id': 'TASK7_PRIVATE_ROW_ID',
              'Authorization': 'Bearer TASK7_PRIVATE_AUTH',
              'url': 'https://private.test/TASK7_PRIVATE_URL',
              'body': 'TASK7_PRIVATE_HTTP_BODY',
              'draft': 'TASK7_PRIVATE_CONTRIBUTOR',
            },
          );
          await transport.settleCaptures();
          expect(transport.events, hasLength(forwardingEnabled ? 1 : 0));
          expect(talker.history.single.exception, same(error));
          expect(talker.history.single.stackTrace, same(stack));
          for (final envelope in transport.envelopes) {
            final payload = await utf8.decoder
                .bind(envelope.envelopeStream(options))
                .join();
            for (final canary in [
              exceptionCanary,
              stackCanary,
              'TASK7_PRIVATE_',
            ]) {
              expect(payload, isNot(contains(canary)));
            }
          }
          final accepted = Sentry.currentHub.scope.breadcrumbs;
          expect(
            accepted
                .where((breadcrumb) => breadcrumb.category == 'console')
                .map((breadcrumb) => breadcrumb.message),
            isEmpty,
          );
          expect(observedConsole, isEmpty);
          final scopeJson = jsonEncode(
            accepted.map((breadcrumb) => breadcrumb.toJson()).toList(),
          );

          expect(scopeJson, isNot(contains('TASK7_PRIVATE_')));
          // Follow-up telemetry inherits the untouched ambient scope.
          final followupId = await Sentry.captureMessage(followupMessage);
          await transport.settleCaptures();
          final envelope = transport.envelopes.singleWhere(
            (envelope) => envelope.header.eventId == followupId,
          );
          final serialized = await utf8.decoder
              .bind(envelope.envelopeStream(options))
              .join();
          expect(serialized, contains(followupMessage));
          expect(serialized, isNot(contains(safeConsole)));
          expect(serialized, isNot(contains('TASK7_PRIVATE_')));
          expect(
            {
              'scope_exception': scopeJson.contains(exceptionCanary),
              'scope_stack': scopeJson.contains(stackCanary),
              'followup_envelope_exception': serialized.contains(
                exceptionCanary,
              ),
              'followup_envelope_stack': serialized.contains(stackCanary),
            },
            {
              'scope_exception': false,
              'scope_stack': false,
              'followup_envelope_exception': false,
              'followup_envelope_stack': false,
            },
          );
        },
      );
    }
  }
}
