import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moliseis/data/repositories/content_submission_api_exception.dart';
import 'package:moliseis/data/repositories/content_submission_repository_impl.dart';
import 'package:moliseis/domain/models/content_submission.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_cloudinary_upload_client.dart';
import '../../support/mock_logger.dart';
import '../../support/recording_supabase_functions_http_client.dart';

void main() {
  late RecordingSupabaseFunctionsHttpClient httpClient;
  late MockLogger logger;
  late SupabaseClient client;
  late ContentSubmissionRepositoryImpl repository;

  final submission = ContentSubmission(
    city: 'Isernia',
    name: 'Visita guidata',
    userEmail: 'author@example.com',
    userName: 'Author',
  );

  Future<Result<void>> submit() => repository.submit(
    clientSubmissionId: '00000000-0000-4000-8000-000000000001',
    contentSubmission: submission,
    submissionAssets: const <SubmissionAsset>[
      SubmissionAsset(
        secureUrl: 'https://res.cloudinary.com/example/image/upload/a.jpg',
        width: 100,
        height: 200,
      ),
    ],
  );

  setUp(() {
    httpClient = RecordingSupabaseFunctionsHttpClient();
    logger = MockLogger();
    client = SupabaseClient(
      'https://test-project.supabase.co',
      'test-publishable-key',
      httpClient: httpClient,
      accessToken: () async => 'test-access-token',
    );
    repository = ContentSubmissionRepositoryImpl(
      logger: logger,
      supabaseClient: client,
      cloudinaryUploadClient: FakeCloudinaryUploadClient(),
    );
  });

  tearDown(() => client.dispose());

  test(
    'sends one exact request and accepts a positive acknowledgement',
    () async {
      httpClient.queueJson(<String, dynamic>{
        'submission_id': 1,
        'extra': true,
      });

      final result = await submit();

      expect(result, isA<Success<void>>());
      expect(httpClient.requests, hasLength(1));
      final request = httpClient.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/functions/v1/submit-content');
      expect(request.headers['authorization'], 'Bearer test-access-token');
      expect(request.body, <String, dynamic>{
        'client_submission_id': '00000000-0000-4000-8000-000000000001',
        'category': null,
        'city': 'Isernia',
        'name': 'Visita guidata',
        'description': null,
        'description_delta': null,
        'latitude': null,
        'longitude': null,
        'address': null,
        'start_date': null,
        'end_date': null,
        'user_email': 'author@example.com',
        'user_name': 'Author',
        'assets': <Map<String, dynamic>>[
          <String, dynamic>{
            'url': 'https://res.cloudinary.com/example/image/upload/a.jpg',
            'width': 100,
            'height': 200,
            'mime_type': null,
            'duration_seconds': null,
          },
        ],
      });
    },
  );

  test('accepts a replay acknowledgement without retrying', () async {
    httpClient.queueJson(<String, dynamic>{
      'submission_id': 1,
      'replayed': true,
    });

    final result = await submit();

    expect(result, isA<Success<void>>());
    expect(httpClient.requests, hasLength(1));
    expect(
      httpClient.requests.single.body,
      containsPair(
        'client_submission_id',
        '00000000-0000-4000-8000-000000000001',
      ),
    );
  });

  for (final invalid in <Object?>[
    null,
    <String, dynamic>{},
    <String, dynamic>{'submission_id': 0},
    <String, dynamic>{'submission_id': -1},
    <String, dynamic>{'submission_id': 1.0},
    <String, dynamic>{'submission_id': '1'},
  ]) {
    test('rejects invalid acknowledgement $invalid', () async {
      httpClient.queueJson(invalid);

      final result = await submit();

      expect(result, isA<Error<void>>());
      expect((result as Error<void>).error, isA<FormatException>());
      expect(httpClient.requests, hasLength(1));
    });
  }

  test('normalizes map Function failures', () async {
    httpClient.queueJson(
      <String, dynamic>{'code': ' invalid_input ', 'message': ' Invalid '},
      status: 400,
    );

    final result = await submit();

    final error =
        (result as Error<void>).error as ContentSubmissionApiException;
    expect(error.statusCode, 400);
    expect(error.code, 'invalid_input');
    expect(error.message, 'Invalid');
    expect(httpClient.requests, hasLength(1));
    expect(logger.eventsOfType<ContentSubmissionUploadFailed>(), hasLength(1));
  });

  for (final failure
      in <({String name, int status, String code, String message})>[
        (
          name: 'validation',
          status: 400,
          code: 'VALIDATION_ERROR',
          message: 'Invalid submission',
        ),
        (
          name: 'authentication',
          status: 401,
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
        ),
        (
          name: 'method',
          status: 405,
          code: 'METHOD_NOT_ALLOWED',
          message: 'Method not allowed',
        ),
        (
          name: 'rate limit',
          status: 429,
          code: 'RATE_LIMIT_EXCEEDED',
          message: 'Rate limit exceeded',
        ),
        (
          name: 'current and legacy internal',
          status: 500,
          code: 'INTERNAL_ERROR',
          message: 'Internal error',
        ),
        (
          name: 'legacy rate-limit read',
          status: 500,
          code: 'RATE_LIMIT_READ_FAILED',
          message: 'Rate-limit read failed',
        ),
        (
          name: 'legacy rate-limit update',
          status: 500,
          code: 'RATE_LIMIT_UPDATE_FAILED',
          message: 'Rate-limit update failed',
        ),
        (
          name: 'legacy submission insert',
          status: 500,
          code: 'SUBMISSION_INSERT_FAILED',
          message: 'Submission insert failed',
        ),
        (
          name: 'legacy asset insert',
          status: 500,
          code: 'ASSET_INSERT_FAILED',
          message: 'Asset insert failed',
        ),
      ]) {
    test('preserves ${failure.name} Function failure fields', () async {
      httpClient.queueJson(
        <String, dynamic>{
          'code': failure.code,
          'message': failure.message,
        },
        status: failure.status,
      );

      final result = await submit();

      expect(result, isA<Error<void>>());
      final error =
          (result as Error<void>).error as ContentSubmissionApiException;
      expect(error.statusCode, failure.status);
      expect(error.code, failure.code);
      expect(error.message, failure.message);
      expect(httpClient.requests, hasLength(1));
    });
  }

  for (final failure
      in <({String name, int status, Object? details, String? code})>[
        (name: 'missing details', status: 500, details: null, code: null),
        (
          name: 'unknown code',
          status: 418,
          details: <String, Object?>{
            'code': 'UNKNOWN_FAILURE',
            'message': 'Unknown',
          },
          code: 'UNKNOWN_FAILURE',
        ),
        (
          name: 'mismatched status and code',
          status: 500,
          details: <String, Object?>{
            'code': 'VALIDATION_ERROR',
            'message': 'Mismatched',
          },
          code: 'VALIDATION_ERROR',
        ),
      ]) {
    test('preserves ${failure.name} as an error', () async {
      httpClient.queueJson(failure.details, status: failure.status);

      final result = await submit();

      expect(result, isA<Error<void>>());
      final error =
          (result as Error<void>).error as ContentSubmissionApiException;
      expect(error.statusCode, failure.status);
      expect(error.code, failure.code);
      expect(httpClient.requests, hasLength(1));
    });
  }

  for (final failure in <({String name, Exception error})>[
    (
      name: 'timeout',
      error: TimeoutException('submit-content timed out'),
    ),
    (name: 'client', error: http.ClientException('transport failed')),
    (name: 'socket', error: const SocketException('network unavailable')),
  ]) {
    test(
      'returns ${failure.name} transport failure after one request',
      () async {
        httpClient.error = failure.error;

        final result = await submit();

        expect(result, isA<Error<void>>());
        expect((result as Error<void>).error, same(failure.error));
        expect(httpClient.requests, hasLength(1));
      },
    );
  }

  test('normalizes string Function failures and transport failures', () async {
    httpClient.queueText('Bad request', status: 400);

    final functionResult = await submit();
    final functionError =
        (functionResult as Error<void>).error as ContentSubmissionApiException;
    expect(functionError.message, 'Bad request');

    httpClient.error = http.ClientException('transport');
    final transportResult = await submit();
    expect(transportResult, isA<Error<void>>());
    expect(httpClient.requests, hasLength(2));
    expect(logger.eventsOfType<ContentSubmissionUploadFailed>(), hasLength(2));
  });

  test(
    'uses reason phrase and stable fallback for incomplete failures',
    () async {
      httpClient
        ..queueJson(
          <String, dynamic>{'code': '  '},
          status: 403,
          reasonPhrase: 'Forbidden',
        )
        ..queueJson(null, status: 500);

      final reasonResult = await submit();
      final fallbackResult = await submit();

      expect(
        ((reasonResult as Error<void>).error as ContentSubmissionApiException)
            .message,
        'Forbidden',
      );
      expect(
        ((fallbackResult as Error<void>).error as ContentSubmissionApiException)
            .message,
        'Content Submission request failed.',
      );
      expect(httpClient.requests, hasLength(2));
    },
  );
}
