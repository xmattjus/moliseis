// Separate response and delay setup keeps each timeout scenario clear.
// ignore_for_file: cascade_invocations

import 'dart:async' show TimeoutException, unawaited;
import 'dart:io' show Directory, File;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_client_impl.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_options.dart';
import 'package:moliseis/data/services/api/cloudinary/exceptions/file_too_large_exception.dart';
import 'package:moliseis/data/services/api/cloudinary/exceptions/upload_cancelled_exception.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/fake_cloudinary_server.dart';
import '../../../../support/mock_logger.dart';

void main() {
  group('CloudinaryUploadClientImpl', () {
    late FakeCloudinaryServer server;
    late MockLogger logger;
    late CloudinaryUploadClientImpl client;

    setUp(() async {
      server = FakeCloudinaryServer();
      await server.start();
      logger = MockLogger();
      client = CloudinaryUploadClientImpl(
        logger: logger,
        cloudName: server.cloudName,
        apiKey: server.apiKey,
        apiSecret: server.apiSecret,
        baseUrl: server.baseUri.toString(),
      );
    });

    tearDown(() async {
      client.dispose();
      await server.stop();
    });

    test(
      'successful upload returns secure_url and reaches progress 1.0',
      () async {
        const secureUrl =
            'https://res.cloudinary.com/test_cloud/image/upload/v1/test';
        server.setUploadResponse(
          status: 200,
          body: const {'secure_url': secureUrl, 'width': 100, 'height': 100},
        );
        final tempDir = await Directory.systemTemp.createTemp('upload_test_');
        final file = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([1, 2, 3, 4, 5]);
        addTearDown(() => tempDir.delete(recursive: true));

        final task = client.uploadImageTask(file);
        final progressValues = <double>[];
        final progressSubscription = task.progress.listen(progressValues.add);

        final result = await task.result;

        await progressSubscription.cancel();
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull()?.secureUrl, secureUrl);
        expect(progressValues, contains(1));
        expect(
          server.requests.where((r) => r.method == 'POST'),
          hasLength(1),
        );

        final uploadRequest = server.requests.firstWhere(
          (r) => r.method == 'POST',
        );
        final body = String.fromCharCodes(uploadRequest.body);
        expect(body, contains('name="signature"'));
        expect(body, contains('name="public_id"'));
        expect(body, contains('name="timestamp"'));
        expect(body, contains('name="api_key"'));
      },
    );

    test(
      'duplicate short-circuit skips upload and returns existing url',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'upload_dup_test_',
        );
        final file = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([1, 2, 3]);
        addTearDown(() => tempDir.delete(recursive: true));

        const publicId = 'content_submissions/abc123';
        const existingUrl =
            'https://res.cloudinary.com/test_cloud/existing.jpg';
        server.addExistingAsset(publicId, existingUrl);

        final task = client.uploadImageTask(
          file,
          options: const CloudinaryUploadOptions(publicId: publicId),
        );
        final progressValues = <double>[];
        final progressSubscription = task.progress.listen(progressValues.add);

        final result = await task.result;

        await progressSubscription.cancel();
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull()?.secureUrl, existingUrl);
        expect(progressValues, contains(1));
        expect(
          server.requests.where((r) => r.method == 'POST'),
          isEmpty,
        );
      },
    );

    test('cancellation returns UploadCancelledException', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'upload_cancel_test_',
      );
      final file = File('${tempDir.path}/image.jpg')
        ..writeAsBytesSync(List<int>.generate(1024 * 1024, (i) => i % 256));
      addTearDown(() => tempDir.delete(recursive: true));

      const publicId = 'content_submissions/cancel_me';
      server.makeNextUploadSlow(publicId);

      final task = client.uploadImageTask(
        file,
        options: const CloudinaryUploadOptions(publicId: publicId),
      );

      // Cancel as soon as bytes actually start streaming.
      unawaited(
        task.progress
            .firstWhere((progress) => progress > 0)
            .then((_) => task.cancel())
            .catchError((Object? _) {}),
      );

      final result = await task.result;

      expect(result.isError, isTrue);
      expect(
        switch (result) {
          Error<SubmissionAsset>(:final error) => error,
          _ => null,
        },
        isA<UploadCancelledException>(),
      );
    });

    test(
      'concurrent uploads allow cancelling one without affecting others',
      () async {
        server.setUploadResponse(
          status: 200,
          body: const {
            'secure_url':
                'https://res.cloudinary.com/test_cloud/image/upload/v1/done',
            'width': 100,
            'height': 100,
          },
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'upload_concurrent_test_',
        );
        final fileA = File('${tempDir.path}/a.jpg')
          ..writeAsBytesSync([1, 2, 3]);
        final fileB = File('${tempDir.path}/b.jpg')
          ..writeAsBytesSync([4, 5, 6]);
        final fileC = File('${tempDir.path}/c.jpg')
          ..writeAsBytesSync([7, 8, 9]);
        addTearDown(() => tempDir.delete(recursive: true));

        final taskA = client.uploadImageTask(
          fileA,
          options: const CloudinaryUploadOptions(
            publicId: 'content_submissions/a',
          ),
        );
        final taskB = client.uploadImageTask(
          fileB,
          options: const CloudinaryUploadOptions(
            publicId: 'content_submissions/b',
          ),
        );
        final taskC = client.uploadImageTask(
          fileC,
          options: const CloudinaryUploadOptions(
            publicId: 'content_submissions/c',
          ),
        );

        server.makeNextUploadSlow('content_submissions/b');

        // Start all three and cancel B as soon as it starts streaming.
        final futures = [
          taskA.result,
          taskB.result,
          taskC.result,
        ];
        unawaited(
          taskB.progress
              .firstWhere((progress) => progress > 0)
              .then((_) => taskB.cancel())
              .catchError((Object? _) {}),
        );

        final results = await Future.wait(futures);

        expect(results[0].isSuccess, isTrue);
        expect(results[1].isError, isTrue);
        expect(
          switch (results[1]) {
            Error<SubmissionAsset>(:final error) => error,
            _ => null,
          },
          isA<UploadCancelledException>(),
        );
        expect(results[2].isSuccess, isTrue);
      },
    );

    test('returns error when upload endpoint returns 400', () async {
      server.setUploadResponse(
        status: 400,
        body: const {'error': 'Bad Request'},
      );
      final tempDir = await Directory.systemTemp.createTemp('http_error_test_');
      final file = File('${tempDir.path}/image.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() => tempDir.delete(recursive: true));

      final task = client.uploadImageTask(file);
      final result = await task.result;

      expect(result.isError, isTrue);
    });

    test('returns error when upload endpoint returns 401', () async {
      server.setUploadResponse(
        status: 401,
        body: const {'error': 'Unauthorized'},
      );
      final tempDir = await Directory.systemTemp.createTemp('http_error_test_');
      final file = File('${tempDir.path}/image.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() => tempDir.delete(recursive: true));

      final task = client.uploadImageTask(file);
      final result = await task.result;

      expect(result.isError, isTrue);
    });

    test(
      'returns error when signature is rejected by the server (401)',
      () async {
        // A client with the wrong API secret produces a signature the fake
        // server (which knows the real secret) rejects, mirroring real
        // Cloudinary behavior. The configured response is 200, so the only
        // way to get an error here is signature validation failing.
        server.setUploadResponse(
          status: 200,
          body: const {
            'secure_url':
                'https://res.cloudinary.com/test_cloud/image/upload/v1/ok',
          },
        );
        final badClient = CloudinaryUploadClientImpl(
          logger: MockLogger(),
          cloudName: server.cloudName,
          apiKey: server.apiKey,
          apiSecret: 'wrong_secret',
          baseUrl: server.baseUri.toString(),
        );
        addTearDown(badClient.dispose);

        final tempDir = await Directory.systemTemp.createTemp(
          'bad_sig_test_',
        );
        final file = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([1, 2, 3]);
        addTearDown(() => tempDir.delete(recursive: true));

        final task = badClient.uploadImageTask(file);
        final result = await task.result;

        expect(result.isError, isTrue);
        final uploadRequest = server.requests.lastWhere(
          (r) => r.method == 'POST',
        );
        expect(uploadRequest, isNotNull);
      },
    );

    test('returns error when upload endpoint returns 500', () async {
      server.setUploadResponse(
        status: 500,
        body: const {'error': 'Internal Server Error'},
      );
      final tempDir = await Directory.systemTemp.createTemp('http_error_test_');
      final file = File('${tempDir.path}/image.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() => tempDir.delete(recursive: true));

      final task = client.uploadImageTask(file);
      final result = await task.result;

      expect(result.isError, isTrue);
    });

    test(
      'retries on HTTP 500 and succeeds on the second attempt with exactly '
      'two POSTs',
      () async {
        server.queueUploadResponses([
          (
            status: 500,
            body: const {'error': 'Internal Server Error'},
          ),
          (
            status: 200,
            body: const {
              'secure_url':
                  'https://res.cloudinary.com/test_cloud/image/upload/v1/retried',
              'width': 100,
              'height': 100,
            },
          ),
        ]);
        final tempDir = await Directory.systemTemp.createTemp(
          'http_500_retry_test_',
        );
        final file = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([1, 2, 3]);
        addTearDown(() => tempDir.delete(recursive: true));

        final task = client.uploadImageTask(file);
        final progressValues = <double>[];
        final progressSubscription = task.progress.listen(progressValues.add);

        final result = await task.result;

        await progressSubscription.cancel();
        expect(result.isSuccess, isTrue);
        expect(
          result.getOrNull()?.secureUrl,
          'https://res.cloudinary.com/test_cloud/image/upload/v1/retried',
        );
        // Exactly two POSTs: the failed 500 and the successful 200.
        expect(
          server.requests.where((r) => r.method == 'POST'),
          hasLength(2),
        );

        // Per-attempt 5xx breadcrumb is logged before the retry.
        final details = logger
            .eventsOfType<CloudinaryRequestFailed>()
            .map((e) => e.detail)
            .toList();
        expect(details, contains('http_500_attempt_1'));
      },
    );

    test(
      'per-attempt timeout aborts the in-flight request and retries until '
      'success',
      () async {
        server.setUploadResponse(
          status: 200,
          body: const {
            'secure_url':
                'https://res.cloudinary.com/test_cloud/image/upload/v1/after_timeout',
            'width': 100,
            'height': 100,
          },
        );
        // Park only the first upload; the second attempt responds immediately.
        server.enqueueSlowUploads(1);

        final tempDir = await Directory.systemTemp.createTemp(
          'timeout_retry_test_',
        );
        final file = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([1, 2, 3, 4, 5]);
        addTearDown(() => tempDir.delete(recursive: true));

        final shortTimeoutClient = CloudinaryUploadClientImpl(
          logger: logger,
          cloudName: server.cloudName,
          apiKey: server.apiKey,
          apiSecret: server.apiSecret,
          baseUrl: server.baseUri.toString(),
          uploadTimeout: const Duration(milliseconds: 100),
        );
        addTearDown(shortTimeoutClient.dispose);

        const publicId = 'content_submissions/timeout_retry';
        final task = shortTimeoutClient.uploadImageTask(
          file,
          options: const CloudinaryUploadOptions(publicId: publicId),
        );
        final progressValues = <double>[];
        final progressSubscription = task.progress.listen(progressValues.add);

        final result = await task.result;

        await progressSubscription.cancel();
        expect(result.isSuccess, isTrue);
        expect(
          result.getOrNull()?.secureUrl,
          'https://res.cloudinary.com/test_cloud/image/upload/v1/after_timeout',
        );

        // Exactly two POSTs: the timed-out attempt (aborted) and the
        // successful retry. If the timed-out attempt were left as a zombie,
        // we would see the slow upload drained by the zombie for the first
        // request AND the retry round-tripping too — i.e. potentially more
        // than one server-side arrival for the same attempt. The two-POST
        // assertion is the regression guard against that zombie bug.
        expect(
          server.requests.where((r) => r.method == 'POST'),
          hasLength(2),
        );

        // Per-attempt timeout breadcrumb.
        final details = logger
            .eventsOfType<CloudinaryRequestFailed>()
            .map((e) => e.detail)
            .toList();
        expect(details, contains('timeout_attempt_1'));

        // Progress must stay monotonically non-decreasing across the
        // timeout and the retry (the bug's symptom #3 was a StateError when
        // the zombie re-emitted progress after the controller had been
        // closed — monotonicity confirms the zombie is gone before the
        // retry emits anything).
        for (var i = 1; i < progressValues.length; i++) {
          expect(
            progressValues[i],
            greaterThanOrEqualTo(progressValues[i - 1]),
            reason:
                'progress regressed at index $i: '
                '${progressValues[i]} < ${progressValues[i - 1]}',
          );
        }
        expect(progressValues, contains(1.0));
      },
    );

    test(
      'per-attempt timeout exhausts retries and returns a TimeoutException',
      () async {
        server.setUploadResponse(
          status: 200,
          body: const {
            'secure_url':
                'https://res.cloudinary.com/test_cloud/image/upload/v1/never',
            'width': 100,
            'height': 100,
          },
        );
        // Park every attempt so each one times out.
        server.enqueueSlowUploads(3);

        final tempDir = await Directory.systemTemp.createTemp(
          'timeout_exhaust_test_',
        );
        final file = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([1, 2, 3, 4, 5]);
        addTearDown(() => tempDir.delete(recursive: true));

        final shortTimeoutClient = CloudinaryUploadClientImpl(
          logger: logger,
          cloudName: server.cloudName,
          apiKey: server.apiKey,
          apiSecret: server.apiSecret,
          baseUrl: server.baseUri.toString(),
          uploadTimeout: const Duration(milliseconds: 100),
        );
        addTearDown(shortTimeoutClient.dispose);

        final task = shortTimeoutClient.uploadImageTask(file);
        final result = await task.result;

        expect(result.isError, isTrue);
        expect(
          switch (result) {
            Error<SubmissionAsset>(:final error) => error,
            _ => null,
          },
          isA<TimeoutException>(),
        );
        // Exactly three POSTs: one per attempt; no zombie dupes.
        expect(
          server.requests.where((r) => r.method == 'POST'),
          hasLength(3),
        );

        // Per-attempt timeout breadcrumbs for the retryable attempts
        // (the third attempt is the terminal one and is logged by
        // [_finalizeUploadResult] as `upload_exception`).
        final details = logger
            .eventsOfType<CloudinaryRequestFailed>()
            .map((e) => e.detail)
            .toList();
        expect(
          details,
          containsAll(['timeout_attempt_1', 'timeout_attempt_2']),
        );
        expect(details, contains('upload_exception'));
      },
    );

    test('returns error when secure_url is absent in 200 response', () async {
      server.setUploadResponse(status: 200, body: const {});
      final tempDir = await Directory.systemTemp.createTemp('http_error_test_');
      final file = File('${tempDir.path}/image.jpg')
        ..writeAsBytesSync([1, 2, 3]);
      addTearDown(() => tempDir.delete(recursive: true));

      final task = client.uploadImageTask(file);
      final result = await task.result;

      expect(result.isError, isTrue);
    });

    test(
      'rejects files exceeding the size limit without opening a connection',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'too_large_test_',
        );
        final file = File('${tempDir.path}/big.jpg')
          ..writeAsBytesSync(
            List<int>.filled(kCloudinaryMaxUploadBytes + 1, 0),
          );
        addTearDown(() => tempDir.delete(recursive: true));

        final task = client.uploadImageTask(file);
        final result = await task.result;

        expect(result.isError, isTrue);
        expect(
          switch (result) {
            Error<SubmissionAsset>(:final error) => error,
            _ => null,
          },
          isA<FileTooLargeException>(),
        );
        // Defense-in-depth: no HTTP traffic should have been made to either
        // the Admin duplicate-lookup or the upload endpoint.
        expect(server.requests, isEmpty);
      },
    );
  });
}
