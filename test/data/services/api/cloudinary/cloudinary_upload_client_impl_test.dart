// Separate response and delay setup keeps each timeout scenario clear.
// Sentry internals inspect delivered envelopes without a production SDK.
// ignore_for_file: cascade_invocations, invalid_use_of_internal_member

import 'dart:async'
    show Completer, TimeoutException, runZonedGuarded, unawaited;
import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, FileSystemException, HttpOverrides;

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_public_id_generator.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_client_impl.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_options.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_preparation.dart';
import 'package:moliseis/data/services/api/cloudinary/exceptions/file_too_large_exception.dart';
import 'package:moliseis/data/services/api/cloudinary/exceptions/upload_cancelled_exception.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../../../support/fake_cloudinary_http_request.dart';
import '../../../../support/fake_cloudinary_server.dart';
import '../../../../support/fake_cloudinary_upload_preparation_client.dart';
import '../../../../support/mock_logger.dart';
import '../../../../support/recording_sentry_transport.dart';

void main() {
  group('CloudinaryUploadClientImpl', () {
    late FakeCloudinaryServer server;
    late MockLogger logger;
    late CloudinaryUploadClientImpl client;
    late FakeCloudinaryUploadPreparationClient preparationClient;

    setUp(() async {
      server = FakeCloudinaryServer();
      await server.start();
      logger = MockLogger();
      preparationClient = FakeCloudinaryUploadPreparationClient();
      client = CloudinaryUploadClientImpl(
        logger: logger,
        cloudName: server.cloudName,
        preparationClient: preparationClient,
        baseUrl: server.baseUri.toString(),
      );
    });

    tearDown(() async {
      client.dispose();
      await server.stop();
    });

    for (final retried in [false, true]) {
      test('POST reuse is truthful, after retry=$retried', () async {
        final directory = await Directory.systemTemp.createTemp('reuse_');
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/image.jpg')..writeAsBytesSync([1]);
        server.queueUploadResponses([
          if (retried)
            (status: 503, body: <String, dynamic>{'error': 'temporary'}),
          (
            status: 200,
            body: <String, dynamic>{
              'secure_url': 'https://res.cloudinary.com/test/reused.jpg',
              'width': 10,
              'height': 20,
              'existing': true,
            },
          ),
        ]);
        final result = await client.uploadImageTask(file).result;
        expect(result.isSuccess, isTrue);
        expect(
          server.requests.where((r) => r.method == 'POST'),
          hasLength(retried ? 2 : 1),
        );
        expect(
          logger.eventsOfType<CloudinaryDuplicateDetected>().single.source,
          CloudinaryReuseSource.response,
        );
        expect(logger.eventsOfType<CloudinaryUploadCompleted>(), isEmpty);
        expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
        expect(
          logger.eventsOfType<CloudinaryUploadRetry>(),
          hasLength(retried ? 1 : 0),
        );
        expect(logger.calls.last.event, isA<CloudinaryDuplicateDetected>());
      });
    }

    for (final failure in [
      'preparation',
      'overwrite',
      'invalid_json',
      'http_400',
      'http_503',
    ]) {
      test('one bounded terminal diagnostic for $failure', () async {
        final directory = await Directory.systemTemp.createTemp('failure_');
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/image.jpg')..writeAsBytesSync([1]);
        if (failure == 'preparation') {
          preparationClient.enqueue(
            Result.error(Exception('private preparation body')),
          );
        } else if (failure == 'invalid_json') {
          server.setUploadResponse(
            status: 200,
            body: {'secure_url': 'invalid'},
          );
        } else {
          server.setUploadResponse(
            status: failure == 'http_503' ? 503 : 400,
            body: {'error': 'private response body'},
          );
        }
        final result = await client
            .uploadImageTask(
              file,
              options: CloudinaryUploadOptions(
                overwrite: failure == 'overwrite',
              ),
            )
            .result;
        expect(result.isError, isTrue);
        final terminal = logger.eventsOfType<CloudinaryRequestFailed>().single;
        expect(terminal.level, AppLogLevel.error);
        expect(terminal.category, switch (failure) {
          'preparation' => CloudinaryFailureCategory.preparation,
          'overwrite' => CloudinaryFailureCategory.validation,
          'invalid_json' => CloudinaryFailureCategory.invalidResponse,
          _ => CloudinaryFailureCategory.http,
        });
        expect(terminal.stage, switch (failure) {
          'preparation' => CloudinaryFailureStage.preparation,
          'overwrite' => CloudinaryFailureStage.preflight,
          'invalid_json' => CloudinaryFailureStage.response,
          _ => CloudinaryFailureStage.upload,
        });
        expect(logger.eventsOfType<CloudinaryUploadCompleted>(), isEmpty);
        expect(
          server.requests.length,
          failure == 'http_503'
              ? 3
              : (failure == 'preparation' || failure == 'overwrite' ? 0 : 1),
        );
        expect(logger.calls.last.event, same(terminal));
      });
    }

    test(
      'missing file keeps its original thrown contract and safe classification',
      () async {
        final directory = await Directory.systemTemp.createTemp('missing_');
        addTearDown(() => directory.delete(recursive: true));
        await expectLater(
          client.uploadImageTask(File('${directory.path}/missing.jpg')).result,
          throwsA(isA<FileSystemException>()),
        );
        final terminal = logger.eventsOfType<CloudinaryRequestFailed>().single;
        expect(terminal.stage, CloudinaryFailureStage.preflight);
        expect(terminal.category, CloudinaryFailureCategory.fileRead);
        expect(server.requests, isEmpty);
      },
    );

    test('file lost after preparation is preflight, without a POST', () async {
      final directory = await Directory.systemTemp.createTemp('lost_file_');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/image.jpg')..writeAsBytesSync([1]);
      final pending = preparationClient.makeNextPreparationPending();
      final task = client.uploadImageTask(file);
      await preparationClient.whenPreparationStarted;
      await file.delete();
      pending.complete(
        Result.success(
          CloudinaryAuthorizedUploadPreparation({
            'public_id': preparationClient.calls.single.publicId,
          }),
        ),
      );
      final result = await task.result;
      expect(result, isA<Error<SubmissionAsset>>());
      final terminal = logger.eventsOfType<CloudinaryRequestFailed>().single;
      expect(terminal.stage, CloudinaryFailureStage.preflight);
      expect(terminal.category, CloudinaryFailureCategory.fileRead);
      expect(server.requests, isEmpty);
    });

    test(
      'cancelled missing file preserves the raw preflight contract',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'cancel_missing_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final task = client.uploadImageTask(
          File('${directory.path}/missing.jpg'),
        );
        task.cancel();
        await expectLater(task.result, throwsA(isA<FileSystemException>()));
        expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
        expect(logger.eventsOfType<CloudinaryUploadCompleted>(), isEmpty);
        expect(preparationClient.calls, isEmpty);
        expect(server.requests, isEmpty);
      },
    );

    for (final consent in [false, true]) {
      test(
        'real HTTP error body stays out of Sentry, consent=$consent',
        () async {
          const canary = 'PRIVATE_HTTP_BODY_AUTH_ROW_ID_CONTRIBUTOR';
          final transport = RecordingSentryTransport();
          await Sentry.init(
            (options) => options
              ..dsn = 'https://abc@example.test/1'
              ..automatedTestMode = true
              ..transport = transport
              ..addEventProcessor(transport)
              ..enablePrintBreadcrumbs = false,
          );
          addTearDown(Sentry.close);
          final talker = TalkerFlutter.init();
          final safeClient = CloudinaryUploadClientImpl(
            logger: AppLogger(
              talker,
              sentryFlag: SentryLoggingFlag(initialValue: consent),
            ),
            cloudName: server.cloudName,
            preparationClient: preparationClient,
            baseUrl: server.baseUri.toString(),
          );
          addTearDown(safeClient.dispose);
          server.setUploadResponse(status: 400, body: {'error': canary});
          final directory = await Directory.systemTemp.createTemp(
            'http_privacy_',
          );
          addTearDown(() => directory.delete(recursive: true));
          final file = File('${directory.path}/image.jpg')
            ..writeAsBytesSync([1]);
          final result = await safeClient.uploadImageTask(file).result;
          expect(result.isError, isTrue);
          expect((result as Error).error.toString(), isNot(contains(canary)));
          await transport.settleCaptures();
          expect(transport.events, hasLength(consent ? 1 : 0));
          expect(transport.envelopes, hasLength(consent ? 1 : 0));
          for (final envelope in transport.envelopes) {
            final serialized = await utf8.decoder
                .bind(envelope.envelopeStream(Sentry.currentHub.options))
                .join();
            expect(serialized, isNot(contains(canary)));
            expect(serialized, contains('UploadDiagnosticFailure'));
          }
          expect(
            talker.history.where(
              (e) => e.message?.contains('cloudinary_request_failed') ?? false,
            ),
            hasLength(1),
          );
        },
      );
    }

    for (final beforeClose in [false, true]) {
      test('request.done has one owner, before close=$beforeClose', () async {
        final directory = await Directory.systemTemp.createTemp('done_fault_');
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/image.jpg')..writeAsBytesSync([1]);

        final escaped = <Object>[];
        final settled = Completer<void>();
        unawaited(
          runZonedGuarded(
            () async {
              final http = FaultingCloudinaryHttpClient(
                beforeClose: beforeClose,
              );
              await HttpOverrides.runZoned(() async {
                final faultClient = CloudinaryUploadClientImpl(
                  logger: logger,
                  cloudName: 'test',
                  preparationClient: preparationClient,
                );
                try {
                  final result = await faultClient.uploadImageTask(file).result;
                  expect(result, isA<Error<SubmissionAsset>>());
                  await Future<void>.delayed(Duration.zero);
                  expect(
                    logger.eventsOfType<CloudinaryRequestFailed>(),
                    hasLength(1),
                  );
                  expect(
                    logger.firstCallOfType<CloudinaryRequestFailed>()!.error,
                    same(http.failure),
                  );
                  expect(http.closeCalled, !beforeClose);
                } finally {
                  faultClient.dispose();
                }
              }, createHttpClient: (_) => http);
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
      });
    }

    test(
      'successful jpg upload returns MIME metadata and reaches progress 1.0',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('upload_test_');
        final file = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([1, 2, 3, 4, 5]);
        addTearDown(() => tempDir.delete(recursive: true));
        final publicId = await CloudinaryPublicIdGenerator().generate(file);
        final secureUrl =
            'https://res.cloudinary.com/test_cloud/image/upload/v1/$publicId.jpg';
        server.setUploadResponse(
          status: 200,
          body: {
            'secure_url': secureUrl,
            'width': 100,
            'height': 100,
            'format': 'jpg',
          },
        );

        final task = client.uploadImageTask(file);
        final progressValues = <double>[];
        final progressSubscription = task.progress.listen(progressValues.add);

        final result = await task.result;

        await progressSubscription.cancel();
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull()?.secureUrl, secureUrl);
        expect(result.getOrNull()?.mimeType, 'image/jpeg');
        expect(progressValues, contains(1));
        expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
        expect(server.requests.where((r) => r.method == 'POST'), hasLength(1));

        final uploadRequest = server.requests.firstWhere(
          (r) => r.method == 'POST',
        );
        expect(uploadRequest.filePartCount, 1);
        expect(uploadRequest.multipartFields, {
          'api_key': 'test-key',
          'public_id': preparationClient.calls.single.publicId,
          'timestamp': '1',
          'overwrite': 'false',
          'upload_preset': 'test-preset',
          'signature': 'test-signature',
        });
      },
    );

    test(
      'uploads an extensionless staged digest file as octet-stream',
      () async {
        server.setUploadResponse(
          status: 200,
          body: const {
            'secure_url':
                'https://res.cloudinary.com/test_cloud/image/upload/v1/staged',
            'width': 100,
            'height': 100,
            'format': 'jpg',
          },
        );
        const payload = <int>[9, 8, 7, 6, 0, 255, 13, 10, 128];
        final digest = sha1.convert(payload).toString();
        final tempDir = await Directory.systemTemp.createTemp('staged_upload_');
        final file = File('${tempDir.path}/$digest')..writeAsBytesSync(payload);
        addTearDown(() => tempDir.delete(recursive: true));

        final result = await client.uploadImageTask(file).result;

        expect(result.isSuccess, isTrue);
        final request = server.requests.singleWhere(
          (request) => request.method == 'POST',
        );
        expect(request.fileParts, hasLength(1));
        final filePart = request.fileParts.single;
        expect(filePart.fieldName, 'file');
        expect(filePart.filename, digest);
        expect(filePart.contentType, 'application/octet-stream');
        expect(filePart.bytes, payload);
      },
    );

    test(
      'successful webp upload maps Cloudinary format to MIME metadata',
      () async {
        server.setUploadResponse(
          status: 200,
          body: const {
            'secure_url':
                'https://res.cloudinary.com/test_cloud/image/upload/v1/webp',
            'width': 100,
            'height': 100,
            'format': 'webp',
          },
        );
        final tempDir = await Directory.systemTemp.createTemp('upload_test_');
        final file = File('${tempDir.path}/image.webp')
          ..writeAsBytesSync([1, 2, 3, 4, 5]);
        addTearDown(() => tempDir.delete(recursive: true));

        final result = await client.uploadImageTask(file).result;

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull()?.mimeType, 'image/webp');
      },
    );

    test(
      'successful upload without a format keeps MIME metadata nullable',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('upload_test_');
        final file = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([1, 2, 3, 4, 5]);
        addTearDown(() => tempDir.delete(recursive: true));
        final publicId = await CloudinaryPublicIdGenerator().generate(file);
        server.setUploadResponse(
          status: 200,
          body: {
            'secure_url':
                'https://res.cloudinary.com/test_cloud/image/upload/v2/$publicId.webp',
            'width': 100,
            'height': 100,
          },
        );

        final result = await client.uploadImageTask(file).result;

        expect(result.isSuccess, isTrue);
        expect(result.getOrNull()?.mimeType, isNull);
      },
    );

    test(
      'duplicate short-circuit skips upload and returns existing MIME metadata',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'upload_dup_test_',
        );
        final file = File('${tempDir.path}/image.jpg')
          ..writeAsBytesSync([1, 2, 3]);
        addTearDown(() => tempDir.delete(recursive: true));

        final publicId = await CloudinaryPublicIdGenerator().generate(file);
        final existingUrl =
            'https://res.cloudinary.com/test_cloud/image/upload/v2/$publicId.webp';
        preparationClient.enqueue(
          Result.success(
            CloudinaryDuplicateUploadPreparation(
              SubmissionAsset(
                secureUrl: existingUrl,
                width: 100,
                height: 100,
                mimeType: 'image/jpeg',
              ),
            ),
          ),
        );

        final task = client.uploadImageTask(file);
        final progressValues = <double>[];
        final progressSubscription = task.progress.listen(progressValues.add);

        final result = await task.result;

        await progressSubscription.cancel();
        expect(result.isSuccess, isTrue);
        expect(result.getOrNull()?.secureUrl, existingUrl);
        expect(result.getOrNull()?.mimeType, 'image/jpeg');
        expect(progressValues, contains(1));
        expect(
          preparationClient.calls.single.publicId,
          matches(RegExp(r'^content_submissions/[0-9a-f]{64}$')),
        );
        expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
        expect(
          logger.eventsOfType<CloudinaryDuplicateDetected>().single.source,
          CloudinaryReuseSource.preparation,
        );
        expect(logger.eventsOfType<CloudinaryUploadCompleted>(), isEmpty);
      },
    );

    test('cancellation returns UploadCancelledException', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'upload_cancel_test_',
      );
      final file = File('${tempDir.path}/image.jpg')
        ..writeAsBytesSync(List<int>.generate(1024 * 1024, (i) => i % 256));
      addTearDown(() => tempDir.delete(recursive: true));

      server.enqueueSlowUploads(1);

      final task = client.uploadImageTask(file);

      // Cancel as soon as bytes actually start streaming.
      unawaited(
        task.progress
            .firstWhere((progress) => progress > 0)
            .then((_) => task.cancel())
            .catchError((Object? _) {}),
      );

      final result = await task.result;

      expect(result.isError, isTrue);
      expect(switch (result) {
        Error<SubmissionAsset>(:final error) => error,
        _ => null,
      }, isA<UploadCancelledException>());
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

        final publicIdB = await CloudinaryPublicIdGenerator().generate(fileB);
        server.makeNextUploadSlow(publicIdB);
        final taskA = client.uploadImageTask(fileA);
        final taskB = client.uploadImageTask(fileB);
        final taskC = client.uploadImageTask(fileC);

        // Start all three and cancel B as soon as it starts streaming.
        final futures = [taskA.result, taskB.result, taskC.result];
        unawaited(
          taskB.progress
              .firstWhere((progress) => progress > 0)
              .then((_) => taskB.cancel())
              .catchError((Object? _) {}),
        );

        final results = await Future.wait(futures);

        expect(results[0].isSuccess, isTrue);
        expect(results[1].isError, isTrue);
        expect(switch (results[1]) {
          Error<SubmissionAsset>(:final error) => error,
          _ => null,
        }, isA<UploadCancelledException>());
        expect(results[2].isSuccess, isTrue);
        expect(preparationClient.calls, hasLength(3));
        expect(
          preparationClient.calls.map((call) => call.publicId),
          everyElement(matches(RegExp(r'^content_submissions/[0-9a-f]{64}$'))),
        );
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

    test('preparation failure prevents a Cloudinary upload request', () async {
      preparationClient.enqueue(Result.error(Exception('preparation failed')));
      final tempDir = await Directory.systemTemp.createTemp('prepare_error_');
      final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([1]);
      addTearDown(() => tempDir.delete(recursive: true));

      final result = await client.uploadImageTask(file).result;

      expect(result.isError, isTrue);
      expect(server.requests, isEmpty);
    });

    test(
      'malformed authorization response failure prevents a Cloudinary POST',
      () async {
        preparationClient.enqueue(
          const Result.error(FormatException('authorized fields are invalid')),
        );
        final tempDir = await Directory.systemTemp.createTemp(
          'prepare_invalid_',
        );
        final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([1]);
        addTearDown(() => tempDir.delete(recursive: true));

        final result = await client.uploadImageTask(file).result;

        expect(result.isError, isTrue);
        final terminal = logger.eventsOfType<CloudinaryRequestFailed>().single;
        expect(terminal.stage, CloudinaryFailureStage.preparation);
        expect(terminal.category, CloudinaryFailureCategory.invalidResponse);
        expect(
          server.requests.where((request) => request.method == 'POST'),
          isEmpty,
        );
      },
    );

    test('overwrite is rejected before a Cloudinary upload request', () async {
      final tempDir = await Directory.systemTemp.createTemp('overwrite_');
      final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([1]);
      addTearDown(() => tempDir.delete(recursive: true));

      final result = await client
          .uploadImageTask(
            file,
            options: const CloudinaryUploadOptions(overwrite: true),
          )
          .result;

      expect(result.isError, isTrue);
      expect(server.requests, isEmpty);
      expect(preparationClient.calls, isEmpty);
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

    test('retries on HTTP 500 and succeeds on the second attempt with exactly '
        'two POSTs', () async {
      server.queueUploadResponses([
        (status: 500, body: const {'error': 'Internal Server Error'}),
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
      expect(server.requests.where((r) => r.method == 'POST'), hasLength(2));
      expect(preparationClient.calls, hasLength(1));

      final retry = logger.eventsOfType<CloudinaryUploadRetry>().single;
      expect(retry.level, AppLogLevel.debug);
      expect(retry.category, CloudinaryFailureCategory.http);
      expect(retry.statusCode, 500);
      expect(retry.attempt, 1);
      expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
      expect(logger.eventsOfType<CloudinaryUploadCompleted>(), hasLength(1));
    });

    test('per-attempt timeout aborts the in-flight request and retries until '
        'success', () async {
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
        preparationClient: preparationClient,
        baseUrl: server.baseUri.toString(),
        uploadTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(shortTimeoutClient.dispose);

      final task = shortTimeoutClient.uploadImageTask(file);
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
      expect(server.requests.where((r) => r.method == 'POST'), hasLength(2));

      expect(
        logger.eventsOfType<CloudinaryUploadRetry>().single.category,
        CloudinaryFailureCategory.timeout,
      );
      expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
      expect(logger.eventsOfType<CloudinaryUploadCompleted>(), hasLength(1));

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
    });

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
          preparationClient: preparationClient,
          baseUrl: server.baseUri.toString(),
          uploadTimeout: const Duration(milliseconds: 100),
        );
        addTearDown(shortTimeoutClient.dispose);

        final task = shortTimeoutClient.uploadImageTask(file);
        final result = await task.result;

        expect(result.isError, isTrue);
        expect(switch (result) {
          Error<SubmissionAsset>(:final error) => error,
          _ => null,
        }, isA<TimeoutException>());
        // Exactly three POSTs: one per attempt; no zombie dupes.
        expect(server.requests.where((r) => r.method == 'POST'), hasLength(3));

        expect(
          logger.eventsOfType<CloudinaryUploadRetry>().map((e) => e.attempt),
          [1, 2],
        );
        expect(
          logger.eventsOfType<CloudinaryRequestFailed>().single.category,
          CloudinaryFailureCategory.timeout,
        );
        expect(logger.eventsOfType<CloudinaryUploadCompleted>(), isEmpty);
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
        final file = File(
          '${tempDir.path}/big.jpg',
        )..writeAsBytesSync(List<int>.filled(kCloudinaryMaxUploadBytes + 1, 0));
        addTearDown(() => tempDir.delete(recursive: true));

        final task = client.uploadImageTask(file);
        final result = await task.result;

        expect(result.isError, isTrue);
        expect(switch (result) {
          Error<SubmissionAsset>(:final error) => error,
          _ => null,
        }, isA<FileTooLargeException>());
        // Defense-in-depth: no HTTP traffic should have been made to either
        // the Admin duplicate-lookup or the upload endpoint.
        expect(server.requests, isEmpty);
        expect(preparationClient.calls, isEmpty);
      },
    );

    test(
      'cancellation before invocation skips preparation and upload',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('cancel_early_');
        final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([1]);
        addTearDown(() => tempDir.delete(recursive: true));

        final task = client.uploadImageTask(file);
        task.cancel();
        final result = await task.result;

        expect(result.isError, isTrue);
        expect(preparationClient.calls, isEmpty);
        expect(server.requests, isEmpty);
        expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
        expect(logger.eventsOfType<CloudinaryUploadCancelled>(), hasLength(1));
      },
    );

    test('cancellation while preparation is pending skips upload', () async {
      final tempDir = await Directory.systemTemp.createTemp('cancel_prepare_');
      final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([1]);
      addTearDown(() => tempDir.delete(recursive: true));
      final pending = preparationClient.makeNextPreparationPending();

      final task = client.uploadImageTask(file);
      await preparationClient.whenPreparationStarted;
      expect(preparationClient.calls, hasLength(1));
      task.cancel();
      pending.complete(
        Result.success(
          CloudinaryAuthorizedUploadPreparation({
            'api_key': 'test-key',
            'public_id': preparationClient.calls.single.publicId,
            'timestamp': '1',
            'overwrite': 'false',
            'upload_preset': 'test-preset',
            'signature': 'test-signature',
          }),
        ),
      );

      final result = await task.result;
      expect(result.isError, isTrue);
      expect(server.requests, isEmpty);
      expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
      expect(logger.eventsOfType<CloudinaryUploadCancelled>(), hasLength(1));
    });

    test(
      'cancellation during retry backoff finishes without another POST',
      () async {
        server.queueUploadResponses([
          (status: 500, body: <String, dynamic>{'error': 'retry'}),
          (
            status: 200,
            body: <String, dynamic>{
              'secure_url': 'https://res.cloudinary.com/test_cloud/done',
              'width': 1,
              'height': 1,
            },
          ),
        ]);
        final backoffStarted = Completer<void>();
        final releaseBackoff = Completer<void>();
        final backoffClient = CloudinaryUploadClientImpl(
          logger: logger,
          cloudName: server.cloudName,
          preparationClient: preparationClient,
          baseUrl: server.baseUri.toString(),
          retryDelay: (_) {
            backoffStarted.complete();
            return releaseBackoff.future;
          },
        );
        addTearDown(backoffClient.dispose);
        final tempDir = await Directory.systemTemp.createTemp(
          'cancel_backoff_',
        );
        final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([1]);
        addTearDown(() => tempDir.delete(recursive: true));

        final task = backoffClient.uploadImageTask(file);
        await backoffStarted.future;
        task.cancel();
        final result = await task.result;

        expect(result.isError, isTrue);
        expect(switch (result) {
          Error<SubmissionAsset>(:final error) => error,
          _ => null,
        }, isA<UploadCancelledException>());
        expect(
          server.requests.where((request) => request.method == 'POST'),
          hasLength(1),
        );
        expect(logger.eventsOfType<CloudinaryRequestFailed>(), isEmpty);
        expect(logger.eventsOfType<CloudinaryUploadCompleted>(), isEmpty);
        expect(logger.eventsOfType<CloudinaryUploadCancelled>(), hasLength(1));
        releaseBackoff.complete();
      },
    );

    test('forwards opaque authorized fields unchanged', () async {
      final tempDir = await Directory.systemTemp.createTemp('opaque_fields_');
      final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([1]);
      addTearDown(() => tempDir.delete(recursive: true));
      final publicId = await CloudinaryPublicIdGenerator().generate(file);
      final fields = {
        'api_key': 'test-key',
        'public_id': publicId,
        'timestamp': '1',
        'overwrite': 'false',
        'upload_preset': 'test-preset',
        'signature': 'test-signature',
        'tags': 'content,special-value',
        'context': 'caption=hello+world|special=%26%3D%7C%25~',
      };
      preparationClient.enqueue(
        Result.success(CloudinaryAuthorizedUploadPreparation(fields)),
      );

      final result = await client.uploadImageTask(file).result;

      expect(result.isSuccess, isTrue);
      expect(server.requests.single.multipartFields, fields);
      expect(server.requests.single.filePartCount, 1);
    });

    test('response-body timeout retries the direct upload', () async {
      final tempDir = await Directory.systemTemp.createTemp('body_timeout_');
      final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([1]);
      addTearDown(() => tempDir.delete(recursive: true));
      final delayed = server.makeNextResponseBodySlow();
      final shortTimeoutClient = CloudinaryUploadClientImpl(
        logger: logger,
        cloudName: server.cloudName,
        preparationClient: preparationClient,
        baseUrl: server.baseUri.toString(),
        uploadTimeout: const Duration(milliseconds: 100),
      );
      addTearDown(shortTimeoutClient.dispose);

      final task = shortTimeoutClient.uploadImageTask(file);
      await delayed.headersSent;
      final result = await task.result;

      expect(result.isSuccess, isTrue);
      expect(
        server.requests.where((request) => request.method == 'POST'),
        hasLength(2),
      );
      delayed.release.complete();
    });

    test('cancellation after response headers cannot return success', () async {
      final tempDir = await Directory.systemTemp.createTemp('body_cancel_');
      final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([1]);
      addTearDown(() => tempDir.delete(recursive: true));
      final delayed = server.makeNextResponseBodySlow();

      final task = client.uploadImageTask(file);
      await delayed.headersSent;
      task.cancel();
      final result = await task.result;

      expect(switch (result) {
        Error<SubmissionAsset>(:final error) => error,
        _ => null,
      }, isA<UploadCancelledException>());
      delayed.release.complete();
    });
  });
}
