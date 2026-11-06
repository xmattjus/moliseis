// The test exercises Sentry's installed native event processor without a
// device. Assertions inspect the delivered envelope, not its mutable event.
// ignore_for_file: invalid_use_of_internal_member, avoid_dynamic_calls

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/enrichment/load_contexts_integration.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/native_context_binding.dart';
import '../../support/recording_sentry_transport.dart';

void main() {
  const nativeCanary = 'NATIVE_PRIVATE_CANARY';
  const queryCanary = 'NATIVE_QUERY_CANARY';
  late NativeContextBinding native;
  late RecordingSentryTransport transport;
  late Talker talker;
  late AppLogger logger;

  setUp(() async {
    native = NativeContextBinding({
      'contexts': {
        'device': {'name': nativeCanary},
      },
      'tags': {'native_private': nativeCanary},
      'extra': {'native_private': nativeCanary},
      'user': {'id': nativeCanary},
      'fingerprint': [nativeCanary],
      'breadcrumbs': [
        {
          'message': 'native_http_request',
          'category': 'http',
          'type': 'http',
          'data': {'url': 'https://example.invalid/?token=$queryCanary'},
        },
      ],
    });
    transport = RecordingSentryTransport();
    talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
    final options = SentryFlutterOptions()
      ..dsn = 'https://abc@example.test/1'
      ..automatedTestMode = true
      ..transport = transport
      ..beforeSend = (event, hint) {
        // Model trace/replay linkage arriving from active SDK context. The
        // controlled private fields exercise the production beforeSend hook.
        final trace =
            event.contexts.trace ??
            SentryTraceContext(
              traceId: SentryId.fromId('11111111111111111111111111111111'),
              spanId: SpanId.fromId('2222222222222222'),
              operation: 'native.operation',
            );
        event.contexts.trace = trace
          ..replayId = SentryId.fromId('33333333333333333333333333333333')
          ..description = nativeCanary
          ..data = {'request': queryCanary};
        return AppLogger.beforeSend(event, hint);
      }
      ..addEventProcessor(transport);
    await Sentry.init((_) {}, options: options);
    // The installed Flutter integration accepts SentryFlutterOptions and adds
    // its real processor to the live options object. A device is unnecessary.
    LoadContextsIntegration(native).call(Sentry.currentHub, options);
    logger = AppLogger(
      talker,
      sentryFlag: SentryLoggingFlag(initialValue: true),
    );
  });

  tearDown(Sentry.close);

  test(
    'app reports restore only approved data after native enrichment',
    () async {
      const error = FormatException('LOCAL_ONLY_ORIGINAL_CAUSE');
      final stack = StackTrace.fromString('LOCAL_ONLY_ORIGINAL_STACK');
      logger
        ..log(const SyncStarted(SyncMode.delta))
        ..log(const SyncContentCommitSucceeded())
        ..log(
          const SyncFailure(
            owner: SyncFailureOwner.settings,
            category: SyncFailureCategory.storage,
          ),
          error: error,
          stackTrace: stack,
        );
      await transport.settleCaptures();

      expect(transport.events, hasLength(1));
      final appEvent = await transport.serializedEvent(0);
      final appJson = jsonEncode(appEvent);
      expect(appJson, isNot(contains(nativeCanary)));
      expect(appJson, isNot(contains(queryCanary)));
      expect(appEvent, isNot(contains('user')));
      expect(appEvent['contexts']['app_diagnostic']['owner'], 'settings');
      expect(appEvent['contexts']['app_diagnostic']['category'], 'storage');
      expect(appEvent['breadcrumbs'].map((dynamic b) => b['message']), [
        'content_sync_started',
        'content_commit_succeeded',
        'content_sync_cause_failed',
      ]);
      final trace = appEvent['contexts']['trace'];
      expect(trace['trace_id'], isNotEmpty);
      expect(trace['span_id'], isNotEmpty);
      expect(trace['replay_id'], '33333333333333333333333333333333');
      expect(trace, isNot(contains('description')));
      expect(trace, isNot(contains('data')));
      expect(
        transport.exceptionValues(appEvent).single['type'],
        'CanonicalSyncFailure',
      );
      expect(talker.history.last.exception, same(error));
      expect(talker.history.last.stackTrace, same(stack));
    },
  );

  test(
    'SDK-owned capture remains untouched by the app-report sanitizer',
    () async {
      await Sentry.captureEvent(
        SentryEvent(
          exceptions: [
            SentryException(type: 'NativeControl', value: 'control event'),
          ],
        ),
      );
      await transport.settleCaptures();

      expect(transport.events, hasLength(1));
      final event = await transport.serializedEvent(0);
      final json = jsonEncode(event);
      expect(json, contains(nativeCanary));
      expect(json, contains(queryCanary));
      expect(
        event['contexts']['trace']['replay_id'],
        '33333333333333333333333333333333',
      );
      expect(event['breadcrumbs'].map((dynamic b) => b['message']), [
        'native_http_request',
      ]);
    },
  );
}
