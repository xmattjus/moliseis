// Installed pipeline controls intentionally inspect SDK scope and options.
// ignore_for_file: invalid_use_of_internal_member, avoid_dynamic_calls
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/use_cases/set_crash_reporting_use_case.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/fake_repositories.dart';
import '../../support/logging_faults.dart';
import '../../support/recording_sentry_transport.dart';

void main() {
  const canary = 'PRIVATE_ENVELOPE_CANARY';
  late RecordingSentryTransport transport;
  late SentryOptions options;
  late SentryLoggingFlag flag;
  late Talker talker;
  late AppLogger logger;

  setUp(() async {
    transport = RecordingSentryTransport();
    await Sentry.init((o) {
      options = o;
      o
        ..dsn = 'https://abc@example.test/1'
        ..automatedTestMode = true
        ..sendDefaultPii = false
        ..enablePrintBreadcrumbs = false
        ..transport = transport
        ..beforeSend = AppLogger.beforeSend
        ..addEventProcessor(transport);
    });
    flag = SentryLoggingFlag(initialValue: true);
    talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
    logger = AppLogger(talker, sentryFlag: flag);
  });
  tearDown(Sentry.close);

  for (final clearScope in [false, true]) {
    for (final restoreEvent in [false, true]) {
      test(
        'scope/event ablation clear=$clearScope restore=$restoreEvent',
        () async {
          // Reproduce the exact two operations independently. The private hint
          // models the approved app copy; no production test switch is needed.
          options.beforeSend = restoreEvent ? AppLogger.beforeSend : null;
          await Sentry.configureScope((scope) async {
            await scope.setUser(SentryUser(id: canary));
            await scope.setTag('private', canary);
            // Exercise the SDK's still-supported legacy scope field boundary.
            // ignore: deprecated_member_use
            await scope.setExtra('private', canary);
            await scope.setContexts('private', {'value': canary});
            scope.addAttachment(
              SentryAttachment.fromIntList(utf8.encode(canary), 'scope.txt'),
            );
          });
          final approved = SentryEvent(
            exceptions: [
              SentryException(type: 'ApplicationFailure', value: 'safe'),
            ],
            breadcrumbs: [Breadcrumb(category: 'app', message: 'safe_control')],
          );
          await Sentry.captureEvent(
            SentryEvent(exceptions: approved.exceptions),
            hint: Hint.withMap({'moliseis.approved_report': approved}),
            withScope: (scope) async {
              if (clearScope) {
                await scope.clear();
                for (final key in scope.contexts.keys.toList()) {
                  await scope.removeContexts(key);
                }
              }
            },
          );
          expect(transport.envelopes, hasLength(1));
          final event = await transport.serializedEvent(0);
          final payload = await transport.serializedEnvelope(0);
          expect(payload, contains('ApplicationFailure'));
          expect(
            jsonEncode(event).contains(canary),
            !clearScope && !restoreEvent,
          );
          // Restoring an event cannot remove scope attachments collected later.
          expect(payload.contains(canary), !clearScope);
          expect(
            transport.envelopes.single.items.where(
              (item) => item.header.type == 'attachment',
            ),
            hasLength(clearScope ? 0 : 1),
          );
          expect(Sentry.currentHub.scope.attachments, hasLength(1));
          expect(Sentry.currentHub.scope.user?.id, canary);
        },
      );
    }
  }

  test(
    'real app capture excludes scope, hint, screenshot and hierarchy bytes',
    () async {
      final attachment = SentryAttachment.fromIntList(
        utf8.encode(canary),
        'private.txt',
      );
      await Sentry.configureScope((scope) => scope.addAttachment(attachment));
      options.addEventProcessor(
        CallbackEventProcessor((event, hint) {
          hint
            ..attachments.add(attachment)
            ..screenshot = attachment
            ..viewHierarchy = attachment;
          event.contexts['processor'] = {'private': canary};
          return event;
        }),
      );
      logger.log(
        const ContentSubmissionDraftLoadFailed(),
        error: StateError(canary),
      );
      await transport.settleCaptures();
      expect(transport.envelopes, hasLength(1));
      expect(transport.envelopes.single.items.map((item) => item.header.type), [
        'event',
      ]);
      expect(await transport.serializedEnvelope(0), isNot(contains(canary)));
      expect(
        (await transport.serializedEvent(
          0,
        ))['contexts']['app_diagnostic']['cause_type'],
        'StateError',
      );
      expect(Sentry.currentHub.scope.attachments, hasLength(1));
      expect(talker.history.single.exception, isA<StateError>());
    },
  );

  test('app clone clearing does not reset the native scope observer', () async {
    final observer = FailingBreadcrumbObserver()..completion.complete();
    options
      ..enableScopeSync = true
      ..addScopeObserver(observer);
    await Sentry.configureScope(
      (scope) => scope.setUser(SentryUser(id: canary)),
    );
    expect(observer.users.single?.id, canary);
    logger.log(
      const ContentSubmissionDraftLoadFailed(),
      error: StateError(canary),
    );
    await transport.settleCaptures();
    expect(transport.envelopes, hasLength(1));
    expect(observer.clearCalls, 0);
    expect(observer.users, hasLength(1));
    expect(Sentry.currentHub.scope.user?.id, canary);
    options.scopeObservers.remove(observer);
  });

  test(
    'delayed app/app/SDK captures retain separate approved payloads',
    () async {
      final entered = List.generate(3, (_) => Completer<void>());
      final release = List.generate(3, (_) => Completer<void>());
      final hints = <Hint>[];
      var index = 0;
      options.addEventProcessor(
        CallbackEventProcessor((event, hint) async {
          final current = index++;
          hints.add(hint);
          event.contexts['private'] = {'value': '$canary$current'};
          hint.attachments.add(
            SentryAttachment.fromIntList(
              utf8.encode('$canary$current'),
              'private$current.txt',
            ),
          );
          entered[current].complete();
          await release[current].future.timeout(const Duration(seconds: 5));
          return event;
        }),
      );
      logger.log(
        const EntityLoadFailed('event', method: 'getById'),
        error: const FormatException(canary),
      );
      await entered[0].future.timeout(const Duration(seconds: 5));
      logger.log(
        const EntityLoadFailed('place', method: 'getAll'),
        error: StateError(canary),
      );
      await entered[1].future.timeout(const Duration(seconds: 5));
      final automatic = Sentry.captureException(StateError(canary));
      await entered[2].future.timeout(const Duration(seconds: 5));
      release[2].complete();
      await automatic;
      release[1].complete();
      release[0].complete();
      await transport.settleCaptures();
      expect(transport.envelopes, hasLength(3));
      expect(hints.toSet(), hasLength(3));
      final events = <Map<String, dynamic>>[];
      for (var i = 0; i < 3; i++) {
        expect(await transport.serializedEnvelope(i), isNot(contains(canary)));
        events.add(await transport.serializedEvent(i));
      }
      final owned = events
          .where((event) => event['contexts']['app_diagnostic'] != null)
          .toList();
      expect(owned, hasLength(2));
      expect(
        owned.map((event) => event['contexts']['app_diagnostic']['entityType']),
        unorderedEquals(['event', 'place']),
      );
      for (final event in owned) {
        expect(event['breadcrumbs'], hasLength(1));
        expect(
          event['breadcrumbs'].single['data']['entityType'],
          event['contexts']['app_diagnostic']['entityType'],
        );
      }
      expect(
        events.where((event) => event['contexts']['app_diagnostic'] == null),
        hasLength(1),
      );
      expect(talker.history, hasLength(2));
    },
  );

  test(
    'one rejected capture does not corrupt an overlapping app report',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      options.addEventProcessor(
        CallbackEventProcessor((event, hint) async {
          if (hint.get('test.reject') == true) {
            entered.complete();
            await release.future.timeout(const Duration(seconds: 5));
            throw StateError(canary);
          }
          return event;
        }),
      );
      final rejected = Sentry.captureException(
        StateError(canary),
        hint: Hint.withMap({'test.reject': true}),
      );
      final rejectedResult = expectLater(rejected, throwsA(isA<StateError>()));
      await entered.future.timeout(const Duration(seconds: 5));
      logger.log(
        const EntityLoadFailed('event', method: 'getById'),
        error: const FormatException(canary),
      );
      await transport.settleEnvelopes(1);
      release.complete();
      await rejectedResult;
      expect(transport.events, hasLength(2));
      expect(transport.envelopes, hasLength(1));
      expect(await transport.serializedEnvelope(0), isNot(contains(canary)));
      expect(
        (await transport.serializedEvent(
          0,
        ))['contexts']['app_diagnostic']['cause_type'],
        'FormatException',
      );
      expect(talker.history, hasLength(1));
    },
  );

  test(
    'effective SDK shutdown separates pending delivery from new capture',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      options.addEventProcessor(
        CallbackEventProcessor((event, hint) async {
          entered.complete();
          await release.future.timeout(const Duration(seconds: 5));
          return event;
        }),
      );
      logger.log(
        const ContentSubmissionDraftLoadFailed(),
        error: StateError(canary),
      );
      await entered.future.timeout(const Duration(seconds: 5));
      final consent = SetCrashReportingUseCase(
        settingsRepository: FakeSettingsRepository(crashReporting: true),
        sentryLoggingFlag: flag,
        initiallyEnabled: true,
        closeSentry: Sentry.close,
      );
      expect(
        (await consent(enable: false)).getOrNull()?.outcome,
        CrashReportingOutcome.disabled,
      );
      expect(flag.enabled, isFalse);
      expect(Sentry.isEnabled, isFalse);
      // Pre-revocation acquisition may finish delivery after shutdown.
      release.complete();
      await transport.settleCaptures();
      expect(transport.envelopes, hasLength(1));
      logger.log(
        const ContentSubmissionDraftLoadFailed(),
        error: StateError('post-shutdown'),
      );
      await Sentry.captureException(StateError('post-shutdown'));
      await transport.settleCaptures();
      expect(transport.events, hasLength(1));
      expect(transport.envelopes, hasLength(1));
      expect(talker.history, hasLength(2));
      expect(
        talker.history.last.exception.toString(),
        contains('post-shutdown'),
      );
      expect(
        (await consent(enable: true)).getOrNull()?.outcome,
        CrashReportingOutcome.enabledForNextStart,
      );
      expect(Sentry.isEnabled, isFalse);
      expect(flag.enabled, isFalse);
    },
  );
  test(
    'automatic scope attachment is an explicit unsupported SDK boundary',
    () async {
      await Sentry.configureScope(
        (scope) => scope.addAttachment(
          SentryAttachment.fromIntList(utf8.encode(canary), 'capability.txt'),
        ),
      );
      await Sentry.captureException(StateError(canary));
      expect(transport.envelopes, hasLength(1));
      expect(
        jsonEncode(await transport.serializedEvent(0)),
        isNot(contains(canary)),
      );
      // This positive capability control is not a privacy pass: scope bytes are
      // read after beforeSend. No app producer exists; acceptance remains open.
      expect(await transport.serializedEnvelope(0), contains(canary));
      expect(transport.envelopes.single.items.map((item) => item.header.type), [
        'event',
        'attachment',
      ]);
    },
  );
}
