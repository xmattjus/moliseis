import 'dart:async' show Completer;
import 'dart:io' show HttpClientRequest, HttpClientResponse;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_cancellation_token.dart';
import 'package:moliseis/utils/logging/log_event.dart';
import 'package:moliseis/utils/logging/logging.dart';

import '../../../../support/mock_logger.dart';

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({this.doneFuture});

  final Future<HttpClientResponse>? doneFuture;

  bool aborted = false;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    aborted = true;
  }

  @override
  Future<HttpClientResponse> get done =>
      doneFuture ?? Future<HttpClientResponse>.value(_FakeHttpClientResponse());

  // -------------------------------------------------------------------------
  // Unused stubs required by the interface.
  // -------------------------------------------------------------------------
  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse implements HttpClientResponse {
  @override
  void noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CloudinaryUploadCancellationToken', () {
    test('cancel before attach aborts as soon as a request is attached', () {
      final token = CloudinaryUploadCancellationToken(logger: MockLogger());
      final request = _FakeHttpClientRequest();

      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(request.aborted, isFalse);

      token.attach(request);
      expect(request.aborted, isTrue);
    });

    test('cancel after attach aborts the attached request', () {
      final token = CloudinaryUploadCancellationToken(logger: MockLogger());
      final request = _FakeHttpClientRequest();

      token.attach(request);
      expect(request.aborted, isFalse);

      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(request.aborted, isTrue);
    });

    test('cancel is idempotent', () {
      final token = CloudinaryUploadCancellationToken(logger: MockLogger());
      final request = _FakeHttpClientRequest();

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
        final request = _FakeHttpClientRequest(
          doneFuture: doneCompleter.future,
        );

        token.attach(request);

        expect(logger.containsEvent<CloudinaryRequestFailed>(), isFalse);

        doneCompleter.completeError(
          Exception('genuine TLS failure'),
          stack,
        );

        // Give the catchError listener a chance to run.
        await Future<void>.delayed(Duration.zero);

        final failedEvents = logger.eventsOfType<CloudinaryRequestFailed>();
        expect(failedEvents, hasLength(1));
        expect(failedEvents.single.detail, 'request_done_error');

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
        final request = _FakeHttpClientRequest(
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

    group('abortCurrentRequest', () {
      test(
        'aborts the attached request without marking the token cancelled',
        () {
          final token = CloudinaryUploadCancellationToken(logger: MockLogger());
          final request = _FakeHttpClientRequest();

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

      test(
        'silences the request.done error log so a timeout-induced abort is '
        'not reported as a genuine server error',
        () async {
          final logger = MockLogger();
          final token = CloudinaryUploadCancellationToken(logger: logger);
          final doneCompleter = Completer<HttpClientResponse>();
          final request = _FakeHttpClientRequest(
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
        },
      );

      test(
        'resets with the next attach so genuine errors are logged again',
        () async {
          final logger = MockLogger();
          final token = CloudinaryUploadCancellationToken(logger: logger);
          final firstDone = Completer<HttpClientResponse>();
          final firstRequest = _FakeHttpClientRequest(
            doneFuture: firstDone.future,
          );

          token
            ..attach(firstRequest)
            ..abortCurrentRequest();
          firstDone.completeError(
            Exception('timeout-induced connection abort'),
          );
          await Future<void>.delayed(Duration.zero);
          // No log for the aborted first request.
          expect(logger.containsEvent<CloudinaryRequestFailed>(), isFalse);
          logger.reset();

          final secondDone = Completer<HttpClientResponse>();
          final secondRequest = _FakeHttpClientRequest(
            doneFuture: secondDone.future,
          );
          token.attach(secondRequest);

          // After re-attaching, a genuine (non-abort) error on the new
          // request must be logged — the per-attempt abort flag must not
          // leak across attempts.
          secondDone.completeError(
            Exception('genuine TLS failure'),
          );
          await Future<void>.delayed(Duration.zero);

          final failedEvents = logger.eventsOfType<CloudinaryRequestFailed>();
          expect(failedEvents, hasLength(1));
          expect(failedEvents.single.detail, 'request_done_error');
          expect(token.isCancelled, isFalse);
        },
      );
    });
  });
}
