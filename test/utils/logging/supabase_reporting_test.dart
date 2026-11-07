// The Sentry SDK fields used below are intentionally internal: this test
// verifies actual scope breadcrumbs and the test-mode event transport.
// ignore_for_file: invalid_use_of_internal_member

import 'dart:convert';
import 'dart:io';

import 'package:command_it/command_it.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moliseis/data/core/supabase_sync_cursor_source.dart';
import 'package:moliseis/data/repositories/city_repository_impl.dart';
import 'package:moliseis/data/services/supabase_anonymous_session.dart';
import 'package:moliseis/utils/command_configuration.dart';
import 'package:moliseis/utils/logging/app_logger.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/mock_supabase.dart';
import '../../support/objectbox_test_store.dart';
import '../../support/recording_sentry_transport.dart';
import '../../support/sdk_boundary_source.dart';

void main() {
  const canary = 'PRIVATE_SUPABASE_FAILURE_CANARY';
  final previousHandler = Command.globalExceptionHandler;
  final previousReportAll = Command.reportAllExceptions;
  late RecordingSentryTransport transport;
  late SentryOptions sdkOptions;
  late SupabaseClient client;
  late AppLogger logger;
  late MockSupabase mockSupabase;
  late TestObjectBoxEnvironment objectBox;
  var responseStatus = 200;
  Exception? requestException;
  StateError? requestError;

  setUpAll(setUpMockSupabase);

  setUp(() async {
    responseStatus = 200;
    requestException = null;
    requestError = null;
    transport = RecordingSentryTransport();
    await Sentry.init((options) {
      sdkOptions = options;
      options
        ..dsn = 'https://abc@def.ingest.sentry.io/1234'
        ..automatedTestMode = true
        ..traceLifecycle = SentryTraceLifecycle.stream
        ..tracesSampleRate = 1
        ..beforeSendSpan = transport.recordSpan
        ..sendDefaultPii = false
        ..transport = transport
        ..addEventProcessor(transport);
    });
    final innerClient = MockClient((request) async {
      if (requestException case final error?) throw error;
      if (requestError case final error?) throw error;
      final body = responseStatus == 200
          ? request.url.path.endsWith('/rpc/get_content_sync_cursor')
                ? jsonEncode('2026-11-06T00:00:00Z')
                : jsonEncode(<Object?>[])
          : jsonEncode({
              'message': 'database unavailable',
              'code': 'XX000',
              'details': canary,
              'hint': '',
            });
      return http.Response(
        body,
        responseStatus,
        request: request,
        headers: const {'content-type': 'application/json'},
        reasonPhrase: responseStatus == 200 ? 'OK' : 'Internal Server Error',
      );
    });
    client = SupabaseClient(
      'https://example.invalid',
      'public-test-key',
      headers: const {'X-Private-Test': 'PRIVATE_HEADER_CANARY'},
      httpClient: SentrySupabaseClient(
        client: innerClient,
        enableErrors: false,
      ),
    );
    mockSupabase = MockSupabase();
    when(() => mockSupabase.client).thenReturn(client);
    objectBox = await TestObjectBoxEnvironment.create();
    logger = AppLogger(
      Talker(settings: TalkerSettings(useConsoleLogs: false)),
      sentryFlag: SentryLoggingFlag(initialValue: true),
    );
  });

  tearDown(() async {
    Command.globalExceptionHandler = previousHandler;
    Command.reportAllExceptions = previousReportAll;
    await objectBox.dispose();
    await Sentry.close();
  });

  test('production disables independent Supabase error capture', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source,
      matches(
        RegExp(
          r'SentrySupabaseClient\(\s*client: httpClient,\s*enableErrors: false,\s*\)',
        ),
      ),
    );
    expect(productionSentryPrivacyConfigured(source), isTrue);
  });

  test(
    'handled cursor connectivity returns Result.error without capture',
    () async {
      requestException = const SocketException(canary);
      final result = await SupabaseSyncCursorSource(
        client,
        logger: logger,
      ).getCurrentCursor();

      expect(result, isA<Error<DateTime>>());
      expect((result as Error<DateTime>).error, same(requestException));
      await transport.settleCaptures();
      expect(transport.events, isEmpty);
      expect(transport.envelopes, isEmpty);
    },
  );

  test(
    'wrapped anonymous auth connectivity is handled without capture',
    () async {
      requestException = const SocketException(canary);

      await ensureAnonymousSupabaseSession(
        authClient: client.auth,
        logger: logger,
      );
      await transport.settleCaptures();

      expect(transport.events, isEmpty);
      expect(transport.envelopes, isEmpty);
    },
  );

  test('anonymous auth HTTP 503 gets one safe status-bearing report', () async {
    responseStatus = 503;

    await ensureAnonymousSupabaseSession(
      authClient: client.auth,
      logger: logger,
    );
    await transport.settleCaptures();

    expect(transport.envelopes, hasLength(1));
    final payload = await utf8.decoder
        .bind(transport.envelopes.single.envelopeStream(SentryOptions()))
        .join();
    expect(payload, contains('status_code'));
    expect(payload, contains('503'));
    expect(payload, isNot(contains(canary)));
  });

  test('cursor HTTP 500 has one application-owned safe report', () async {
    responseStatus = 500;
    final result = await SupabaseSyncCursorSource(
      client,
      logger: logger,
    ).getCurrentCursor();

    expect(result, isA<Error<DateTime>>());
    await transport.settleCaptures();

    expect(transport.envelopes, hasLength(1));
    final event = transport.events.single;
    expect(event.throwableMechanism, isNull);
    expect(
      event.exceptions?.any(
        (exception) => exception.type == 'CanonicalSyncFailure',
      ),
      isTrue,
    );
    expect(event.sdk?.integrations, contains('sentrySupabaseBreadcrumbs'));
    expect(event.sdk?.integrations, contains('sentrySupabaseTracing'));
    final payload = await utf8.decoder
        .bind(transport.envelopes.single.envelopeStream(SentryOptions()))
        .join();
    expect(payload, isNot(contains(canary)));
    expect(payload, contains('PostgrestException'));
    expect(payload, contains('XX000'));
  });

  test('city repository owns shared-client HTTP 500 reporting', () async {
    responseStatus = 500;
    final repository = CityRepositoryImpl(
      logger: logger,
      supabaseI: mockSupabase,
      objectBoxI: TestObjectBox(objectBox.store),
    );

    final result = await repository.prepareSync();

    expect(result.isError, isTrue, reason: '$result');
    await transport.settleCaptures();
    expect(transport.envelopes, hasLength(1));
    final event = transport.events.single;
    expect(event.throwableMechanism, isNull);
    expect(
      event.exceptions?.any(
        (exception) => exception.type == 'CanonicalSyncFailure',
      ),
      isTrue,
    );
    final payload = await utf8.decoder
        .bind(transport.envelopes.single.envelopeStream(SentryOptions()))
        .join();
    expect(payload, isNot(contains(canary)));
    expect(payload, contains('XX000'));
  });

  test(
    'unexpected city fetch throw reaches command reporting unchanged',
    () async {
      final failure = StateError(canary);
      requestError = failure;
      final repository = CityRepositoryImpl(
        logger: logger,
        supabaseI: mockSupabase,
        objectBoxI: TestObjectBox(objectBox.store),
      );
      configureCommandReporting(logger);

      await expectLater(repository.prepareSync, throwsA(same(failure)));
      Command.globalExceptionHandler!(
        CommandError<void>(error: failure),
        StackTrace.current,
      );
      await transport.settleCaptures();

      expect(transport.envelopes, hasLength(1));
      final payload = await utf8.decoder
          .bind(transport.envelopes.single.envelopeStream(SentryOptions()))
          .join();
      expect(payload, isNot(contains(canary)));
      expect(transport.events.single.throwableMechanism, isNull);
    },
  );

  test('shared client retains Supabase database breadcrumbs', () async {
    await Sentry.startSpan('test-operation', (_) async {
      await client.from('cities').select();
    });
    await transport.settleSpans(2);

    expect(
      transport.spans.map((span) => span.name),
      containsAll(['test-operation', 'from(cities)']),
    );
    expect(
      Sentry.currentHub.scope.breadcrumbs.any(
        (breadcrumb) => breadcrumb.category == 'db.select',
      ),
      isTrue,
    );
  });

  test(
    'SDK breadcrumb and span keep request values out of remote telemetry',
    () async {
      const queryCanary = 'PRIVATE_QUERY_CANARY';
      const headerCanary = 'PRIVATE_HEADER_CANARY';

      await Sentry.startSpan('private-query-test', (_) async {
        await client.from('cities').select().eq('name', queryCanary);
      });
      await transport.settleSpans(2);
      await Sentry.captureMessage('safe Supabase telemetry control');
      await transport.settleCaptures();

      final eventPayload = await utf8.decoder
          .bind(transport.envelopes.single.envelopeStream(SentryOptions()))
          .join();
      final spanPayload = jsonEncode(
        transport.spans
            .map(
              (span) => span.attributes.map(
                (key, attribute) => MapEntry(key, attribute.toJson()),
              ),
            )
            .toList(),
      );
      final breadcrumbPayload = jsonEncode(
        Sentry.currentHub.scope.breadcrumbs
            .map((breadcrumb) => breadcrumb.toJson())
            .toList(),
      );

      expect(transport.events, hasLength(1));
      expect(transport.events.single.exceptions, isNull);
      expect(eventPayload, contains('db.select'));
      expect(eventPayload, contains('cities'));
      expect(eventPayload, contains('select'));
      expect(breadcrumbPayload, contains('db.select'));
      for (final payload in [eventPayload, spanPayload, breadcrumbPayload]) {
        expect(payload, isNot(contains(queryCanary)));
        expect(payload, isNot(contains(headerCanary)));
      }

      // beforeSendSpan is not the wire boundary. Flush the installed batching
      // processor and inspect its independently serialized span envelope.
      await sdkOptions.telemetryProcessor.flush();
      final spanEnvelopes = transport.envelopes.where(
        (envelope) => envelope.items.any((item) => item.header.type == 'span'),
      );
      expect(spanEnvelopes, hasLength(1));
      final serializedSpans = await transport.serializedEnvelope(
        transport.envelopes.indexOf(spanEnvelopes.single),
      );
      expect(serializedSpans, contains('from(cities)'));
      expect(serializedSpans, contains('SELECT'));
      expect(serializedSpans, contains('?'));
      expect(serializedSpans, isNot(contains(queryCanary)));
      expect(serializedSpans, isNot(contains(headerCanary)));
    },
  );

  for (final pii in [false, true]) {
    test('Supabase body/query acquisition control PII=$pii', () async {
      const privateValue = 'PRIVATE_BODY_QUERY_CONTROL';
      sdkOptions
        ..sendDefaultPii = pii
        ..maxRequestBodySize = MaxRequestBodySize.always;
      final bodyClient = SentrySupabaseClient(
        client: MockClient((request) async => http.Response('{}', 200)),
        enableErrors: false,
      );
      addTearDown(bodyClient.close);
      await Sentry.startSpan('body-query-control', (_) async {
        await client.from('cities').select().eq('name', privateValue);
        // The installed body reader accepts http.Request, whereas Postgrest
        // can supply a streamed request. Use a real acquired body control.
        await bodyClient.send(
          http.Request(
            'PATCH',
            Uri.parse('https://example.invalid/rest/v1/cities'),
          )..body = jsonEncode({'name': privateValue}),
        );
      });
      await transport.settleSpans(3);
      await Sentry.captureMessage('safe database control');
      await transport.settleCaptures();
      await sdkOptions.telemetryProcessor.flush();

      final eventEnvelopes = transport.envelopes.where(
        (envelope) => envelope.items.any((item) => item.header.type == 'event'),
      );
      final spanEnvelopes = transport.envelopes.where(
        (envelope) => envelope.items.any((item) => item.header.type == 'span'),
      );
      expect(eventEnvelopes, hasLength(1));
      expect(spanEnvelopes, hasLength(1));
      for (final envelope in [eventEnvelopes.single, spanEnvelopes.single]) {
        final payload = await transport.serializedEnvelope(
          transport.envelopes.indexOf(envelope),
        );
        expect(payload, contains('cities'));
        // StreamingInstrumentationSpan.setData rejects Map bodies even with
        // PII enabled; breadcrumbs supply the acquired body/query control.
        final isEvent = envelope.items.any(
          (item) => item.header.type == 'event',
        );
        expect(payload.contains(privateValue), pii && isEvent);
        if (!isEvent) {
          expect(payload, contains('UPDATE'));
          expect(payload, contains('SELECT'));
          expect(payload, contains('?'));
        }
      }
      expect(
        transport.spans.map((span) => span.name),
        containsAll(['from(cities)', 'body-query-control']),
      );
    });
  }
  test(
    'automatic policy retains acquired Supabase operation breadcrumbs',
    () async {
      sdkOptions.beforeSend = AppLogger.beforeSend;
      await client.from('cities').select().eq('name', canary);
      await Sentry.captureException(StateError(canary));
      expect(transport.envelopes, hasLength(1));
      final event = await transport.serializedEvent(0);
      expect(transport.exceptionValues(event).single['type'], 'StateError');
      expect(event['breadcrumbs'], hasLength(1));
      final breadcrumbs = (event['breadcrumbs'] as List)
          .cast<Map<String, dynamic>>();
      expect(breadcrumbs.single['data'], {
        'table': 'cities',
        'operation': 'select',
      });
      expect(await transport.serializedEnvelope(0), isNot(contains(canary)));
    },
  );
}
