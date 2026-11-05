import 'dart:async'
    show Completer, TimeoutException, runZonedGuarded, unawaited;
import 'dart:io' show HttpClientResponse;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_cancellation_token.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logging.dart';

import '../../../../support/fake_cloudinary_http_request.dart';
import '../../../../support/mock_logger.dart';

void main() {
  group('CloudinaryUploadCancellationToken', () {
    test('cancel before attach aborts as soon as a request is attached', () {
      final token = CloudinaryUploadCancellationToken(logger: MockLogger());
      final request = FakeCloudinaryHttpRequest();

      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(request.aborted, isFalse);

      token.attach(request);
      expect(request.aborted, isTrue);
    });

    test('cancel after attach aborts the attached request', () {
      final token = CloudinaryUploadCancellationToken(logger: MockLogger());
      final request = FakeCloudinaryHttpRequest();

      token.attach(request);
      expect(request.aborted, isFalse);

      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(request.aborted, isTrue);
    });

    test('cancel is idempotent', () {
      final token = CloudinaryUploadCancellationToken(logger: MockLogger());
      final request = FakeCloudinaryHttpRequest();

      token
        ..attach(request)
        ..cancel()
        ..cancel()
        ..cancel();

      expect(token.isCancelled, isTrue);
      expect(request.aborted, isTrue);
    });

    test('isCancelled is false until cancel is called', () {
      final token = CloudinaryUploadCancellationToken(logger: MockLogger());

      expect(token.isCancelled, isFalse);
    });

    test(
      'logs a CloudinaryRequestFailed when request.done errors and the token '
      'was not cancelled',
      () async {
        final logger = MockLogger();
        final token = CloudinaryUploadCancellationToken(logger: logger);
        final stack = StackTrace.fromString('test stack');
        final doneCompleter = Completer<HttpClientResponse>();
        final request = FakeCloudinaryHttpRequest(
          doneFuture: doneCompleter.future,
        );

        token.attach(request);

        expect(logger.containsEvent<CloudinaryRequestFailed>(), isFalse);

        doneCompleter.completeError(Exception('genuine TLS failure'), stack);

        // Give the catchError listener a chance to run.
        await Future<void>.delayed(Duration.zero);

        expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
        token.finish();
        final failedEvents = logger.eventsOfType<CloudinaryRequestFailed>();
        expect(failedEvents, hasLength(1));
        expect(
          failedEvents.single.category,
          CloudinaryFailureCategory.transport,
        );

        final record = logger.firstCallOfType<CloudinaryRequestFailed>();
        expect(record?.error, isA<Exception>());
        expect(record?.stackTrace, stack);
        expect(token.isCancelled, isFalse);
      },
    );

    test(
      'silently swallows request.done errors when the token was cancelled',
      () async {
        final logger = MockLogger();
        final token = CloudinaryUploadCancellationToken(logger: logger);
        final doneCompleter = Completer<HttpClientResponse>();
        final request = FakeCloudinaryHttpRequest(
          doneFuture: doneCompleter.future,
        );

        token
          ..attach(request)
          ..cancel();

        doneCompleter.completeError(
          Exception('abort-induced connection closed'),
        );

        // Give the catchError listener a chance to run.
        await Future<void>.delayed(Duration.zero);

        expect(logger.containsEvent<CloudinaryRequestFailed>(), isFalse);
        expect(token.isCancelled, isTrue);
        expect(request.aborted, isTrue);
      },
    );

    for (final late in [false, true]) {
      test(
        'otherwise-unobserved fault is retained, after finish=$late',
        () async {
          final escaped = <Object>[];
          final settled = Completer<void>();
          unawaited(
            runZonedGuarded(
              () async {
                final logger = MockLogger();
                final token = CloudinaryUploadCancellationToken(logger: logger);
                final done = Completer<HttpClientResponse>();
                final failure = Exception('otherwise unobserved');
                token.attach(
                  FakeCloudinaryHttpRequest(doneFuture: done.future),
                );
                if (late) token.finish();
                done.completeError(failure);
                await Future<void>.delayed(Duration.zero);
                if (!late) {
                  expect(logger.calls, isEmpty);
                  token.finish();
                }
                token.finish();
                expect(
                  logger.eventsOfType<CloudinaryRequestFailed>(),
                  hasLength(1),
                );
                expect(logger.calls.single.error, same(failure));
                settled.complete();
              },
              (error, stack) {
                escaped.add(error);
                if (!settled.isCompleted) settled.complete();
              },
            ),
          );
          await settled.future;
          expect(escaped, isEmpty);
        },
      );
    }

    test(
      'a retry owns an early fault and late callbacks cannot revive it',
      () async {
        final logger = MockLogger();
        final token = CloudinaryUploadCancellationToken(logger: logger);
        final done = Completer<HttpClientResponse>();
        token.attach(FakeCloudinaryHttpRequest(doneFuture: done.future));
        done.completeError(Exception('passive transport failure'));
        await done.future.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        );
        final mainCause = TimeoutException('main timeout');
        token
          ..reportRetry(
            const CloudinaryUploadRetry(
              category: CloudinaryFailureCategory.timeout,
              attempt: 1,
            ),
            mainCause,
          )
          ..finish();
        expect(logger.eventsOfType<CloudinaryUploadRetry>(), hasLength(1));
        expect(
          logger.firstCallOfType<CloudinaryUploadRetry>()!.error,
          same(mainCause),
        );
        expect(
          logger.firstCallOfType<CloudinaryUploadRetry>()!.stackTrace,
          isNull,
        );
        expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
      },
    );

    for (final passiveFirst in [true, false]) {
      test(
        'main cause matches classification, passiveFirst=$passiveFirst',
        () async {
          final logger = MockLogger();
          final token = CloudinaryUploadCancellationToken(logger: logger);
          final done = Completer<HttpClientResponse>();
          final passive = Exception('passive transport failure');
          final main = TimeoutException('main timeout');
          final stack = StackTrace.fromString('main timeout stack');
          token.attach(FakeCloudinaryHttpRequest(doneFuture: done.future));
          if (passiveFirst) {
            done.completeError(passive);
            await done.future.then<void>(
              (_) {},
              onError: (Object _, StackTrace _) {},
            );
          }
          token
            ..reportFailure(
              const CloudinaryRequestFailed(
                stage: CloudinaryFailureStage.upload,
                category: CloudinaryFailureCategory.timeout,
              ),
              main,
              stack,
            )
            ..finish();
          if (!passiveFirst) {
            done.completeError(passive);
            await done.future.then<void>(
              (_) {},
              onError: (Object _, StackTrace _) {},
            );
          }
          token.finish();
          expect(logger.eventsOfType<CloudinaryRequestFailed>(), hasLength(1));
          final call = logger.firstCallOfType<CloudinaryRequestFailed>()!;
          expect(call.error, same(main));
          expect(call.stackTrace, same(stack));
          expect(
            (call.event as CloudinaryRequestFailed).category,
            CloudinaryFailureCategory.timeout,
          );
        },
      );
    }

    for (final retry in [false, true]) {
      test('same passive cause retains its stack, retry=$retry', () async {
        final logger = MockLogger();
        final token = CloudinaryUploadCancellationToken(logger: logger);
        final done = Completer<HttpClientResponse>();
        final cause = TimeoutException('same observed failure');
        final stack = StackTrace.fromString('original passive stack');
        token.attach(FakeCloudinaryHttpRequest(doneFuture: done.future));
        done.completeError(cause, stack);
        await done.future.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        );
        if (retry) {
          token.reportRetry(
            const CloudinaryUploadRetry(
              category: CloudinaryFailureCategory.timeout,
              attempt: 1,
            ),
            cause,
          );
        } else {
          token.reportFailure(
            const CloudinaryRequestFailed(
              stage: CloudinaryFailureStage.upload,
              category: CloudinaryFailureCategory.timeout,
            ),
            cause,
            null,
          );
        }
        token.finish();
        expect(logger.calls, hasLength(1));
        expect(logger.calls.single.error, same(cause));
        expect(logger.calls.single.stackTrace, same(stack));
      });
    }

    for (final succeeds in [true, false]) {
      test(
        'late previous attempt cannot contaminate retry success=$succeeds',
        () async {
          final logger = MockLogger();
          final token = CloudinaryUploadCancellationToken(logger: logger);
          final first = Completer<HttpClientResponse>();
          final second = Completer<HttpClientResponse>();
          token.attach(FakeCloudinaryHttpRequest(doneFuture: first.future));
          final retryCause = TimeoutException('retry timeout');
          token
            ..reportRetry(
              const CloudinaryUploadRetry(
                category: CloudinaryFailureCategory.timeout,
                attempt: 1,
              ),
              retryCause,
            )
            ..attach(FakeCloudinaryHttpRequest(doneFuture: second.future));
          first.completeError(Exception('obsolete transport failure'));
          await first.future.then<void>(
            (_) {},
            onError: (Object _, StackTrace _) {},
          );
          if (succeeds) {
            second.complete(FakeCloudinaryHttpResponse());
            await second.future;
          } else {
            final cause = TimeoutException('second timeout');
            token.reportFailure(
              const CloudinaryRequestFailed(
                stage: CloudinaryFailureStage.upload,
                category: CloudinaryFailureCategory.timeout,
              ),
              cause,
              null,
            );
            second.completeError(cause);
            await second.future.then<void>(
              (_) {},
              onError: (Object _, StackTrace _) {},
            );
            expect(
              logger.firstCallOfType<CloudinaryRequestFailed>()!.error,
              same(cause),
            );
          }
          token.finish();
          expect(
            logger.eventsOfType<CloudinaryRequestFailed>(),
            hasLength(succeeds ? 0 : 1),
          );
          expect(
            logger.firstCallOfType<CloudinaryUploadRetry>()!.error,
            same(retryCause),
          );
        },
      );
    }

    test('cancel after passive fault suppresses terminal reporting', () async {
      final logger = MockLogger();
      final token = CloudinaryUploadCancellationToken(logger: logger);
      final done = Completer<HttpClientResponse>();
      token.attach(FakeCloudinaryHttpRequest(doneFuture: done.future));
      done.completeError(Exception('transport failure'));
      await done.future.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      token
        ..cancel()
        ..reportFailure(
          const CloudinaryRequestFailed(
            stage: CloudinaryFailureStage.upload,
            category: CloudinaryFailureCategory.transport,
          ),
          Exception('main failure'),
          null,
        )
        ..finish();
      expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
    });

    group('abortCurrentRequest', () {
      test(
        'aborts the attached request without marking the token cancelled',
        () {
          final token = CloudinaryUploadCancellationToken(logger: MockLogger());
          final request = FakeCloudinaryHttpRequest();

          token.attach(request);
          expect(request.aborted, isFalse);
          expect(token.isCancelled, isFalse);

          token.abortCurrentRequest();

          // The request is aborted by the timer (or pipeline), but the token
          // remains usable for the next attempt.
          expect(request.aborted, isTrue);
          expect(token.isCancelled, isFalse);
        },
      );

      test('is idempotent and safe to call with no attached request', () {
        final token = CloudinaryUploadCancellationToken(logger: MockLogger());

        expect(() {
          token.abortCurrentRequest();
          // The repeated receiver makes the idempotence action under test
          // explicit.
          // ignore: cascade_invocations
          token.abortCurrentRequest();
        }, returnsNormally);
        expect(token.isCancelled, isFalse);
      });

      test('silences the request.done error log so a timeout-induced abort is '
          'not reported as a genuine server error', () async {
        final logger = MockLogger();
        final token = CloudinaryUploadCancellationToken(logger: logger);
        final doneCompleter = Completer<HttpClientResponse>();
        final request = FakeCloudinaryHttpRequest(
          doneFuture: doneCompleter.future,
        );

        token
          ..attach(request)
          ..abortCurrentRequest();

        // The abort-induced `request.done` error lands on the passive
        // listener while `_abortedForRetry` is true — it must NOT be
        // logged as `request_done_error`.
        doneCompleter.completeError(
          Exception('timeout-induced connection abort'),
        );
        await Future<void>.delayed(Duration.zero);

        expect(logger.containsEvent<CloudinaryRequestFailed>(), isFalse);
        expect(token.isCancelled, isFalse);
      });

      test(
        'does not log a delayed timeout-aborted request after a retry attaches',
        () async {
          final logger = MockLogger();
          final token = CloudinaryUploadCancellationToken(logger: logger);
          final firstDone = Completer<HttpClientResponse>();
          final firstRequest = FakeCloudinaryHttpRequest(
            doneFuture: firstDone.future,
          );

          token
            ..attach(firstRequest)
            ..abortCurrentRequest();

          final secondDone = Completer<HttpClientResponse>();
          final secondRequest = FakeCloudinaryHttpRequest(
            doneFuture: secondDone.future,
          );
          token.attach(secondRequest);

          // The first request's expected abort error must stay tied to its
          // own attachment even though a retry has replaced the active one.
          firstDone.completeError(
            Exception('timeout-induced connection abort'),
          );
          await Future<void>.delayed(Duration.zero);
          expect(logger.containsEvent<CloudinaryRequestFailed>(), isFalse);

          // A genuine error from the currently attached retry remains
          // observable and must not inherit the prior attempt's suppression.
          secondDone.completeError(Exception('genuine TLS failure'));
          await Future<void>.delayed(Duration.zero);

          token.finish();
          final failedEvents = logger.eventsOfType<CloudinaryRequestFailed>();
          expect(failedEvents, hasLength(1));
          expect(
            failedEvents.single.category,
            CloudinaryFailureCategory.transport,
          );
          expect(token.isCancelled, isFalse);
        },
      );
    });
  });
}
