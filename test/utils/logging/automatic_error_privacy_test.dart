// Host tests exercise SDK entry integrations, not mobile crash delivery.
// ignore_for_file: invalid_use_of_internal_member, avoid_dynamic_calls
// ignore_for_file: cascade_invocations
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/app_logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_flutter/src/bindings/platform_dispatcher_wrapper.dart';
import 'package:sentry_flutter/src/exception/flutter_error_integration.dart';

import '../../support/logging_faults.dart';
import '../../support/recording_sentry_transport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const private = 'AUTOMATIC_PRIVATE_CANARY';
  final stack = StackTrace.fromString(
    '#0 $private (package:moliseis/data/repositories/event_repository_impl.dart:42:7)\n'
    '#1 $private (file:///private/$private/$private.dart:13:1)',
  );

  for (final filtered in [false, true]) {
    test('genuinely unhandled zone error, filtered=$filtered', () async {
      final transport = RecordingSentryTransport();
      final caught = Completer<Object>();
      final error = StateError(private);
      addTearDown(Sentry.close);
      await Sentry.init(
        (options) {
          options
            ..dsn = 'https://abc@example.test/1'
            ..sendDefaultPii = false
            ..enablePrintBreadcrumbs = false
            ..automatedTestMode = true
            ..transport = transport
            ..beforeSend = filtered ? AppLogger.beforeSend : null
            ..addEventProcessor(transport);
        },
        appRunner: () {
          scheduleMicrotask(() => Error.throwWithStackTrace(error, stack));
        },
        runZonedGuardedOnError: (error, _) => caught.complete(error),
      );
      expect(
        await caught.future.timeout(const Duration(seconds: 5)),
        same(error),
      );
      await transport.settleCaptures();
      expect(transport.envelopes, hasLength(1));
      final event = await transport.serializedEvent(0);
      final exception = transport.exceptionValues(event).single;
      expect(exception['type'], 'StateError');
      expect(exception['mechanism'], {
        'type': 'runZonedGuarded',
        'handled': false,
      });
      expect(exception['stacktrace']['frames'], isNotEmpty);
      expect(jsonEncode(event).contains(private), !filtered);
      if (filtered) {
        expect(exception['stacktrace']['frames'].single['lineno'], 42);
        expect(event['contexts'], isNot(contains('app_diagnostic')));
      }
    });
  }

  for (final entry in ['framework', 'dispatcher']) {
    test('$entry filters scope and preserves SDK ownership', () async {
      final transport = RecordingSentryTransport();
      final options = SentryFlutterOptions()
        ..dsn = 'https://abc@example.test/1'
        ..sendDefaultPii = false
        ..enablePrintBreadcrumbs = false
        ..automatedTestMode = true
        ..transport = transport
        ..beforeSend = AppLogger.beforeSend
        ..addEventProcessor(transport);
      await Sentry.init((_) {}, options: options);
      final oldFlutter = FlutterError.onError;
      final oldPlatform = PlatformDispatcher.instance.onError;
      addTearDown(() async {
        await Sentry.close();
        FlutterError.onError = oldFlutter;
        PlatformDispatcher.instance.onError = oldPlatform;
      });
      await Sentry.configureScope((scope) async {
        await scope.setUser(SentryUser(email: private));
        await scope.setTag('private', private);
        // Exercise legacy scope content retained by the pinned SDK.
        // ignore: deprecated_member_use
        await scope.setExtra('private', private);
        await scope.setContexts('private', {'body': private});
        await scope.addBreadcrumb(
          Breadcrumb(message: private, category: 'console'),
        );
      });
      if (entry == 'framework') {
        FlutterError.onError = null;
        final integration = FlutterErrorIntegration();
        integration.call(Sentry.currentHub, options);
        addTearDown(integration.close);
        // Flutter's real reporting entry; its installed hook creates the event.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: StateError(private),
            stack: stack,
            library: private,
            context: ErrorDescription(private),
            informationCollector: () => [ErrorDescription(private)],
          ),
        );
      } else {
        PlatformDispatcher.instance.onError = null;
        final integration = OnErrorIntegration(
          dispatchWrapper: PlatformDispatcherWrapper(
            PlatformDispatcher.instance,
          ),
        );
        integration.call(Sentry.currentHub, options);
        addTearDown(integration.close);
        // Host invocation; mobile engine delivery still needs runtime evidence.
        expect(
          integration.dispatchWrapper!.onError!(StateError(private), stack),
          isFalse,
        );
      }
      await transport.settleCaptures();
      expect(transport.envelopes, hasLength(1));
      final event = await transport.serializedEvent(0);
      final exception = transport.exceptionValues(event).single;
      expect(exception['type'], 'StateError');
      expect(
        exception['mechanism']['type'],
        entry == 'framework' ? 'FlutterError' : 'PlatformDispatcher.onError',
      );
      expect(exception['mechanism']['handled'], isFalse);
      expect(exception['stacktrace']['frames'].single['lineno'], 42);
      expect(jsonEncode(event), isNot(contains(private)));
      expect(event['contexts'], isNot(contains('app_diagnostic')));
    });
  }

  test(
    'chains, missing stacks and malformed contexts retain safe visibility',
    () async {
      final transport = RecordingSentryTransport();
      await Sentry.init((options) {
        options
          ..dsn = 'https://abc@example.test/1'
          ..automatedTestMode = true
          ..transport = transport
          ..beforeSend = (event, hint) {
            if (event.contexts['malformed'] == true) {
              event.contexts['trace'] = private;
            }
            return AppLogger.beforeSend(event, hint);
          }
          ..addEventProcessor(transport);
      });
      addTearDown(Sentry.close);
      for (final malformed in [false, true]) {
        final contexts = Contexts()..['private'] = private;
        if (malformed) contexts['malformed'] = true;
        await Sentry.captureEvent(
          SentryEvent(
            contexts: contexts,
            exceptions: [
              SentryException(
                type: private,
                value: private,
                mechanism: Mechanism(
                  type: 'generic',
                  handled: false,
                  description: private,
                  data: {'private': private},
                  exceptionId: 1,
                  parentId: 0,
                ),
              ),
              SentryException(
                type: 'StateError',
                value: private,
                mechanism: Mechanism(
                  type: 'FlutterError',
                  handled: false,
                  exceptionId: 0,
                ),
              ),
            ],
          ),
        );
      }
      expect(transport.envelopes, hasLength(2));
      final chain = transport.exceptionValues(
        await transport.serializedEvent(0),
      );
      expect(chain, hasLength(2));
      expect(chain.first['mechanism']['parent_id'], 0);
      expect(chain.last['mechanism']['exception_id'], 0);
      final fallback = transport.exceptionValues(
        await transport.serializedEvent(1),
      );
      expect(fallback, hasLength(2));
      expect(fallback.last['type'], 'StateError');
      expect(fallback.last['mechanism']['handled'], isFalse);
      for (var i = 0; i < 2; i++) {
        expect(
          jsonEncode(await transport.serializedEvent(i)),
          isNot(contains(private)),
        );
      }
    },
  );
  test(
    'projection failure retains a bounded error, never the unsafe input',
    () async {
      final transport = RecordingSentryTransport();
      await Sentry.init(
        (options) => options
          ..dsn = 'https://abc@example.test/1'
          ..automatedTestMode = true
          ..beforeSend = AppLogger.beforeSend
          ..transport = transport
          ..addEventProcessor(transport),
      );
      addTearDown(Sentry.close);
      await Sentry.captureEvent(
        SentryEvent(
          exceptions: [
            SentryException(
              type: 'StateError',
              value: private,
              stackTrace: SentryStackTrace(frames: [FaultySentryStackFrame()]),
            ),
          ],
        ),
      );
      expect(transport.envelopes, hasLength(1));
      final event = await transport.serializedEvent(0);
      expect(
        transport.exceptionValues(event).single['value'],
        'Diagnostic filtering failed',
      );
      expect(await transport.serializedEnvelope(0), isNot(contains(private)));
    },
  );

  test(
    'automatic AOT addresses and debug IDs survive without private image paths',
    () async {
      final transport = RecordingSentryTransport();
      final image = DebugMeta()
        ..addDebugImage(
          DebugImage(
            type: 'macho',
            debugId: '12345678-1234-1234-1234-123456789abc',
            imageAddr: '0x10fa20000',
            imageSize: 5000000,
            name: private,
            codeFile: '/private/$private/App',
            debugFile: private,
          ),
        );
      await Sentry.init(
        (options) => options
          ..dsn = 'https://abc@example.test/1'
          ..automatedTestMode = true
          ..beforeSend = AppLogger.beforeSend
          ..transport = transport
          ..addEventProcessor(transport)
          ..addEventProcessor(
            CallbackEventProcessor((event, hint) {
              event.debugMeta = image;
              return event;
            }),
          ),
      );
      addTearDown(Sentry.close);
      await Sentry.captureException(
        StateError(private),
        stackTrace: StackTrace.fromString(
          '#00 abs 000000010fa3e26d _kDartIsolateSnapshotInstructions+0x1e26d7',
        ),
      );
      expect(transport.envelopes, hasLength(1));
      final event = await transport.serializedEvent(0);
      final frames =
          transport.exceptionValues(event).single['stacktrace']['frames']
              as List;
      expect(frames.single['instruction_addr'], '0x000000010fa3e26d');
      expect(frames.single['platform'], 'native');
      expect(
        event['debug_meta']['images'].single['debug_id'],
        '12345678-1234-1234-1234-123456789abc',
      );
      expect(event['debug_meta']['images'].single['image_addr'], '0x10fa20000');
      expect(await transport.serializedEnvelope(0), isNot(contains(private)));
    },
  );
  test(
    'genuine unhandled chain traverses SDK extraction and grouping',
    () async {
      final transport = RecordingSentryTransport();
      final caught = Completer<Object>();
      final error = ChainedDiagnosticException(StateError(private), stack);
      await Sentry.init(
        (options) => options
          ..dsn = 'https://abc@example.test/1'
          ..automatedTestMode = true
          ..groupExceptions = true
          ..enablePrintBreadcrumbs = false
          ..beforeSend = AppLogger.beforeSend
          ..transport = transport
          ..addExceptionCauseExtractor(DiagnosticCauseExtractor())
          ..addEventProcessor(transport),
        appRunner: () => scheduleMicrotask(() => throw error),
        runZonedGuardedOnError: (error, _) => caught.complete(error),
      );
      addTearDown(Sentry.close);
      expect(
        await caught.future.timeout(const Duration(seconds: 5)),
        same(error),
      );
      await transport.settleCaptures();
      expect(transport.envelopes, hasLength(1));
      final values = transport.exceptionValues(
        await transport.serializedEvent(0),
      );
      expect(values, hasLength(2));
      expect(values.first['type'], 'StateError');
      expect(values.first['mechanism']['type'], 'chained');
      expect(values.first['mechanism']['parent_id'], 0);
      expect(values.last['mechanism']['type'], 'runZonedGuarded');
      expect(values.last['mechanism']['handled'], isFalse);
      expect(values.first['stacktrace']['frames'].single['lineno'], 42);
      expect(await transport.serializedEnvelope(0), isNot(contains(private)));
    },
  );
  for (final enabled in [false, true]) {
    test('console acquisition positive control enabled=$enabled', () async {
      final transport = RecordingSentryTransport();
      await Sentry.init(
        (options) => options
          ..dsn = 'https://abc@example.test/1'
          ..automatedTestMode = true
          ..enablePrintBreadcrumbs = enabled
          ..beforeSend = AppLogger.beforeSend
          ..transport = transport
          ..addEventProcessor(transport),
        appRunner: () {
          // Exercise the installed zone print-acquisition integration.
          // ignore: avoid_print
          print(private);
        },
      );
      addTearDown(Sentry.close);
      final acquired = Sentry.currentHub.scope.breadcrumbs
          .where((breadcrumb) => breadcrumb.category == 'console')
          .toList();
      expect(acquired, hasLength(enabled ? 1 : 0));
      if (enabled) expect(acquired.single.message, private);
      await Sentry.captureException(StateError(private));
      expect(transport.envelopes, hasLength(1));
      final event = await transport.serializedEvent(0);
      expect(transport.exceptionValues(event).single['type'], 'StateError');
      expect(await transport.serializedEnvelope(0), isNot(contains(private)));
    });
  }
}
