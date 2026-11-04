// SDK test configuration and scope processors verify capture behavior.
// ignore_for_file: invalid_use_of_internal_member

import 'dart:core' as core;
import 'dart:core';

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/logging/run_traced_result.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry/sentry.dart';

import '../../support/recording_sentry_transport.dart';

void main() {
  late RecordingSentryTransport transport;

  setUp(() async {
    transport = RecordingSentryTransport();
    await Sentry.init((options) {
      options
        ..dsn = 'https://abc@example.test/1'
        ..automatedTestMode = true
        ..traceLifecycle = SentryTraceLifecycle.stream
        ..tracesSampleRate = 1.0
        ..transport = transport
        ..beforeSendSpan = transport.recordSpan;
    });
    Sentry.currentHub.scope.addEventProcessor(transport);
  });

  tearDown(Sentry.close);

  for (final failed in [false, true]) {
    test(
      'records ${failed ? 'error' : 'ok'} for original Result once',
      () async {
        final result = failed
            ? Result<int>.error(Exception('original'))
            : const Result<int>.success(7);
        var calls = 0;

        final actual = await runTracedResult('result-operation', () async {
          calls++;
          return result;
        });
        await transport.settleSpans(1);

        expect(actual, same(result));
        expect(calls, 1);
        final span = transport.spans.single;
        expect(span.name, 'result-operation');
        expect(span.isEnded, isTrue);
        expect(
          span.status,
          failed ? SentrySpanStatusV2.error : SentrySpanStatusV2.ok,
        );
        await transport.settleCaptures();
        expect(transport.events, isEmpty);
        await Sentry.close();
        expect(transport.envelopes, isNotEmpty);
      },
    );
  }

  for (final error in [StateError('unexpected'), Object(), 'thrown string']) {
    test(
      'preserves unexpected ${error.runtimeType} and stack without capture',
      () async {
        final stack = StackTrace.fromString('original-stack');
        var calls = 0;
        try {
          await runTracedResult<void>('throwing-operation', () async {
            calls++;
            core.Error.throwWithStackTrace(error, stack);
          });
          fail('Expected original throw');
        } on Object catch (actual, actualStack) {
          expect(actual, same(error));
          expect(actualStack.toString(), stack.toString());
        }
        await transport.settleSpans(1);
        expect(calls, 1);
        expect(transport.spans.single.status, SentrySpanStatusV2.error);
        await transport.settleCaptures();
        expect(transport.events, isEmpty);
      },
    );
  }

  for (final enabled in [false, true]) {
    test(
      'executes once when ${enabled ? 'sampled out' : 'disabled'}',
      () async {
        await Sentry.close();
        if (enabled) {
          await Sentry.init((options) {
            options
              ..dsn = 'https://abc@example.test/1'
              ..automatedTestMode = true
              ..traceLifecycle = SentryTraceLifecycle.stream
              ..tracesSampleRate = 0.0
              ..transport = transport
              ..beforeSendSpan = transport.recordSpan;
          });
        }
        var calls = 0;
        const result = Result<int>.success(1);
        expect(
          await runTracedResult('inactive', () async {
            calls++;
            return result;
          }),
          same(result),
        );
        final returnedError = Result<int>.error(Exception('returned'));
        expect(
          await runTracedResult('inactive', () async {
            calls++;
            return returnedError;
          }),
          same(returnedError),
        );
        final error = Object();
        final stack = StackTrace.fromString('inactive-stack');
        try {
          await runTracedResult<void>('inactive', () async {
            calls++;
            core.Error.throwWithStackTrace(error, stack);
          });
          fail('Expected original throw');
        } on Object catch (actual, actualStack) {
          expect(actual, same(error));
          expect(actualStack.toString(), stack.toString());
        }
        expect(calls, 3);
        expect(transport.spans, isEmpty);
        expect(transport.events, isEmpty);
      },
    );
  }
}
