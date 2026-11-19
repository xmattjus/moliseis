// Assertions inspect the installed SDK's final serialized event.
// ignore_for_file: avoid_dynamic_calls, invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../support/recording_sentry_transport.dart';

void main() {
  const private = 'PRIVATE_LOCALIZATION_CANARY';
  late RecordingSentryTransport transport;
  late Talker talker;
  late AppLogger logger;

  setUp(() async {
    transport = RecordingSentryTransport();
    talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
    logger = AppLogger(
      talker,
      sentryFlag: SentryLoggingFlag(initialValue: true),
    );
    await Sentry.init((options) {
      options
        ..dsn = 'https://abc@example.test/1'
        ..automatedTestMode = true
        ..sendDefaultPii = false
        ..beforeSend = AppLogger.beforeSend
        ..transport = transport
        ..addEventProcessor(transport);
    });
  });
  tearDown(Sentry.close);

  test(
    'same-category failures retain distinct reviewed source locations',
    () async {
      final errors = List.generate(
        2,
        (index) => FormatException('$private$index'),
      );
      final stacks = [
        StackTrace.fromString(
          '#0 $private (package:moliseis/data/repositories/event_repository_impl.dart:42:7)\n'
          '#1 $private (file:///private/$private/$private.dart:1:1)',
        ),
        StackTrace.fromString(
          '#0 $private (package:moliseis/ui/explore/view_models/explore_view_model.dart:88:4)\n'
          '#1 $private (package:moliseis/$private.dart:1:1)',
        ),
      ];
      for (var i = 0; i < errors.length; i++) {
        logger.log(
          const EntityLoadFailed('event', method: 'getById'),
          error: errors[i],
          stackTrace: stacks[i],
        );
      }
      await transport.settleCaptures();
      expect(transport.envelopes, hasLength(2));
      final first = transport
          .exceptionValues(await transport.serializedEvent(0))
          .single;
      final second = transport
          .exceptionValues(await transport.serializedEvent(1))
          .single;
      expect(first['type'], second['type']);
      expect(first['value'], second['value']);
      expect(first['stacktrace']['frames'].single['lineno'], 42);
      expect(second['stacktrace']['frames'].single['lineno'], 88);
      expect(
        second['stacktrace']['frames'].single['abs_path'],
        'package:moliseis/ui/explore/view_models/explore_view_model.dart',
      );
      expect(first['stacktrace'], isNot(second['stacktrace']));
      for (var i = 0; i < errors.length; i++) {
        expect(await transport.serializedEnvelope(i), isNot(contains(private)));
        expect(talker.history[i].exception, same(errors[i]));
        expect(talker.history[i].stackTrace, same(stacks[i]));
      }
    },
  );

  test(
    'upload envelope keeps canonical locations and excludes private input',
    () async {
      const sources = [
        'package:moliseis/data/repositories/content_submission_repository_impl.dart',
        'package:flutter/src/widgets/framework.dart',
        'dart:async/future_impl.dart',
      ];
      final error = StateError('PRIVATE_UPLOAD_ERROR_MESSAGE');
      final stack = StackTrace.fromString(
        '#0 PRIVATE_RAW_METHOD (${sources[0]}:42:7)\n'
        '#1 PRIVATE_RAW_METHOD (${sources[1]}:42:7)\n'
        '#2 PRIVATE_RAW_METHOD (${sources[2]}:42:7)\n'
        '#3 f (file:///private/PRIVATE_NONCANONICAL_PATH.dart:42:7)\n'
        '#4 f (package:moliseis/PRIVATE_UNSUPPORTED_PATH.dart:42:7)\n'
        'PRIVATE_RAW_STACK_TEXT',
      );
      const ambient = 'PRIVATE_AMBIENT_CONTEXT';
      const extra = {
        'authorization': 'PRIVATE_AUTHORIZATION',
        'url': 'https://example.test/PRIVATE_URL',
        'body': 'PRIVATE_REQUEST_BODY',
        'contributor': 'PRIVATE_CONTRIBUTOR',
        'error_metadata': 'PRIVATE_ERROR_METADATA',
      };
      await Sentry.configureScope(
        (scope) => scope.setContexts('private', {'value': ambient}),
      );
      logger.log(
        const ContentSubmissionUploadFailed(),
        error: error,
        stackTrace: stack,
        extra: extra,
      );
      await transport.settleCaptures();
      expect(transport.events, hasLength(1));
      expect(transport.envelopes, hasLength(1));
      final exception = transport
          .exceptionValues(await transport.serializedEvent(0))
          .single;
      final frames = exception['stacktrace']['frames'] as List<dynamic>;
      expect(
        frames.map((frame) => frame['abs_path']),
        unorderedEquals(sources),
      );
      for (final frame in frames) {
        expect(frame['lineno'], 42);
        expect(frame['colno'], 7);
        expect(frame, isNot(contains('function')));
      }
      final envelope = await transport.serializedEnvelope(0);
      for (final canary in [
        'PRIVATE_UPLOAD_ERROR_MESSAGE',
        'PRIVATE_RAW_METHOD',
        'PRIVATE_NONCANONICAL_PATH',
        'PRIVATE_UNSUPPORTED_PATH',
        'PRIVATE_RAW_STACK_TEXT',
        ambient,
        ...extra.values,
      ]) {
        expect(envelope, isNot(contains(canary)));
      }
      expect(talker.history.single.exception, same(error));
      expect(talker.history.single.stackTrace, same(stack));
    },
  );

  for (final stack in <String?>[
    null,
    private,
    '#0 f (package:moliseis/data/dtos/event_dto.mapper.dart:1:1)',
    '#00 abs 000000723d6346d7 _kDartIsolateSnapshotInstructions+0x1e26d7',
    '#0 f (file:///private/$private/event_repository_impl.dart:1:1)',
    '#0 f (package:moliseis/data/repositories/event_repository_impl.dart?$private:1:1)',
  ]) {
    test(
      'missing, generated, AOT or unsafe stack stays bounded: $stack',
      () async {
        logger.log(
          const EntityLoadFailed('event', method: 'getById'),
          error: const FormatException(private),
          stackTrace: stack == null ? null : StackTrace.fromString(stack),
        );
        await transport.settleCaptures();
        expect(transport.envelopes, hasLength(1));
        final event = await transport.serializedEvent(0);
        final exception = transport.exceptionValues(event).single;
        expect(exception['type'], 'ApplicationFailure');
        expect(exception['value'], contains('FormatException'));
        expect(exception, isNot(contains('stacktrace')));
        expect(await transport.serializedEnvelope(0), isNot(contains(private)));
      },
    );
  }
}
