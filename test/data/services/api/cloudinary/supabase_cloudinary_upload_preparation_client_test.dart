import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_options.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_preparation.dart';
import 'package:moliseis/data/services/api/cloudinary/supabase_cloudinary_upload_preparation_client.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/recording_supabase_functions_http_client.dart';

void main() {
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const publicId = 'content_submissions/$digest';
  const secureUrl =
      'https://res.cloudinary.com/test-cloud/image/upload/v1/$publicId.jpg';
  late RecordingSupabaseFunctionsHttpClient httpClient;
  late SupabaseClient supabase;
  late SupabaseCloudinaryUploadPreparationClient client;

  setUp(() {
    httpClient = RecordingSupabaseFunctionsHttpClient();
    supabase = SupabaseClient(
      'https://test-project.supabase.co',
      'test-publishable-key',
      httpClient: httpClient,
      accessToken: () async => 'test-access-token',
    );
    client = SupabaseCloudinaryUploadPreparationClient(client: supabase);
  });
  tearDown(() => supabase.dispose());

  test('sends exact intent and parses authorized fields', () async {
    httpClient.queueJson(<String, Object?>{
      'outcome': 'authorized',
      'fields': <String, Object?>{
        'api_key': 'runtime-key',
        'public_id': publicId,
        'timestamp': '1',
        'overwrite': 'false',
        'upload_preset': 'preset',
        'signature': 'signature',
        'tags': 'content',
      },
    });
    final result = await client.prepare(
      publicId: publicId,
      options: const CloudinaryUploadOptions(tags: ['content']),
    );
    expect(result, isA<Success<CloudinaryUploadPreparation>>());
    expect(
      httpClient.requests.single.url.path,
      '/functions/v1/prepare-cloudinary-upload',
    );
    expect(
      httpClient.requests.single.headers['authorization'],
      'Bearer test-access-token',
    );
    expect(httpClient.requests.single.body, <String, Object?>{
      'content_sha256': digest,
      'max_width': 2048,
      'max_height': 2048,
      'tags': <String>['content'],
      'context': <String, String>{},
      'overwrite': false,
    });
  });

  test('parses a duplicate asset', () async {
    httpClient.queueJson(<String, Object?>{
      'outcome': 'duplicate',
      'asset': <String, Object?>{
        'secure_url': secureUrl,
        'width': 100,
        'height': 200,
        'mime_type': 'image/jpeg',
        'duration_seconds': null,
      },
    });
    final result = await client.prepare(
      publicId: publicId,
      options: const CloudinaryUploadOptions(),
    );
    expect(result.getOrNull(), isA<CloudinaryDuplicateUploadPreparation>());
  });

  test('accepts additive response-envelope and duplicate-asset metadata', () {
    final authorized =
        SupabaseCloudinaryUploadPreparationClient.parseResponseForTesting(
          <String, Object?>{
            'outcome': 'authorized',
            'fields': <String, Object?>{
              'api_key': 'runtime-key',
              'public_id': publicId,
              'timestamp': '1',
              'overwrite': 'false',
              'upload_preset': 'preset',
              'signature': 'signature',
            },
            'metadata': <String, Object?>{'version': 1},
          },
          publicId,
        );
    final duplicate =
        SupabaseCloudinaryUploadPreparationClient.parseResponseForTesting(
          <String, Object?>{
            'outcome': 'duplicate',
            'asset': <String, Object?>{
              'secure_url': secureUrl,
              'width': 100,
              'height': 200,
              'mime_type': 'image/jpeg',
              'duration_seconds': null,
              'metadata': <String, Object?>{'version': 1},
            },
            'metadata': <String, Object?>{'duplicate': true},
          },
          publicId,
        );

    expect(authorized, isA<CloudinaryAuthorizedUploadPreparation>());
    expect(duplicate, isA<CloudinaryDuplicateUploadPreparation>());
  });

  test('maps function, transport, and malformed responses to errors', () async {
    httpClient
      ..queueJson({'message': 'forbidden'}, status: 403)
      ..queueJson({'outcome': 'unexpected'});
    final first = await client.prepare(
      publicId: publicId,
      options: const CloudinaryUploadOptions(),
    );
    final second = await client.prepare(
      publicId: publicId,
      options: const CloudinaryUploadOptions(),
    );
    httpClient.error = http.ClientException('offline');
    final third = await client.prepare(
      publicId: publicId,
      options: const CloudinaryUploadOptions(),
    );
    expect(first, isA<Error<CloudinaryUploadPreparation>>());
    expect(second, isA<Error<CloudinaryUploadPreparation>>());
    expect(third, isA<Error<CloudinaryUploadPreparation>>());
  });

  for (final failure
      in <
        ({
          String name,
          int status,
          String code,
          String message,
          String reasonPhrase,
        })
      >[
        (
          name: 'validation',
          status: 400,
          code: 'VALIDATION_ERROR',
          message: 'Invalid preparation request',
          reasonPhrase: 'Bad Request',
        ),
        (
          name: 'authentication',
          status: 401,
          code: 'UNAUTHORIZED',
          message: 'Authentication required',
          reasonPhrase: 'Unauthorized',
        ),
        (
          name: 'method',
          status: 405,
          code: 'METHOD_NOT_ALLOWED',
          message: 'Method not allowed',
          reasonPhrase: 'Method Not Allowed',
        ),
        (
          name: 'request size',
          status: 413,
          code: 'REQUEST_TOO_LARGE',
          message: 'Request too large',
          reasonPhrase: 'Content Too Large',
        ),
        (
          name: 'configuration',
          status: 500,
          code: 'CLOUDINARY_CONFIGURATION_ERROR',
          message: 'Configuration mismatch',
          reasonPhrase: 'Internal Server Error',
        ),
        (
          name: 'ambiguous preparation',
          status: 502,
          code: 'CLOUDINARY_PREPARATION_ERROR',
          message: 'Temporary-looking preparation failure',
          reasonPhrase: 'Bad Gateway',
        ),
        (
          name: 'unknown',
          status: 418,
          code: 'UNKNOWN_FAILURE',
          message: 'Unknown temporary-looking failure',
          reasonPhrase: 'Unknown Failure',
        ),
        (
          name: 'mismatched',
          status: 500,
          code: 'VALIDATION_ERROR',
          message: 'Mismatched failure',
          reasonPhrase: 'Internal Server Error',
        ),
      ]) {
    test(
      '${failure.name} Function response remains an ordinary error',
      () async {
        httpClient.queueJson(
          <String, Object?>{
            'code': failure.code,
            'message': failure.message,
          },
          status: failure.status,
          reasonPhrase: failure.reasonPhrase,
        );

        final result = await client.prepare(
          publicId: publicId,
          options: const CloudinaryUploadOptions(),
        );

        expect(result, isA<Error<CloudinaryUploadPreparation>>());
        expect(
          (result as Error<CloudinaryUploadPreparation>).error,
          isA<Exception>(),
        );
        expect(httpClient.requests, hasLength(1));
      },
    );
  }

  for (final failure in <({String name, Exception error})>[
    (
      name: 'timeout',
      error: TimeoutException('preparation timed out'),
    ),
    (name: 'client', error: http.ClientException('offline')),
    (name: 'socket', error: const SocketException('network unavailable')),
  ]) {
    test(
      '${failure.name} transport failure remains an ordinary error',
      () async {
        httpClient.error = failure.error;

        final result = await client.prepare(
          publicId: publicId,
          options: const CloudinaryUploadOptions(),
        );

        expect(result, isA<Error<CloudinaryUploadPreparation>>());
        expect(
          (result as Error<CloudinaryUploadPreparation>).error,
          same(failure.error),
        );
        expect(httpClient.requests, hasLength(1));
      },
    );
  }

  test('rejects every malformed map shape as a FormatException', () {
    final validFields = <String, Object?>{
      'api_key': 'runtime-key',
      'public_id': publicId,
      'timestamp': '1',
      'overwrite': 'false',
      'upload_preset': 'preset',
      'signature': 'signature',
    };
    final invalidResponses = <Object?>[
      <Object?, Object?>{1: 'not-a-string-key'},
      <String, Object?>{
        'outcome': 'authorized',
        'fields': <Object?, Object?>{1: 'value'},
      },
      <String, Object?>{
        'outcome': 'authorized',
        'fields': <String, Object?>{...validFields, 'signature': 1},
      },
      <String, Object?>{
        'outcome': 'authorized',
        'fields': <String, Object?>{...validFields, 'unexpected': 'value'},
      },
      <String, Object?>{
        'outcome': 'authorized',
        'fields': <String, Object?>{...validFields, 'api_key': ''},
      },
      <String, Object?>{
        'outcome': 'authorized',
        'fields': <String, Object?>{...validFields, 'upload_preset': ''},
      },
      <String, Object?>{
        'outcome': 'authorized',
        'fields': <String, Object?>{...validFields, 'signature': ''},
      },
      <String, Object?>{
        'outcome': 'authorized',
        'fields': <String, Object?>{...validFields, 'timestamp': '01'},
      },
      <String, Object?>{
        'outcome': 'authorized',
        'fields': <String, Object?>{
          ...validFields,
          'timestamp': '9007199254740992',
        },
      },
      <String, Object?>{'outcome': 'authorized', 'fields': 'not-a-map'},
      <String, Object?>{
        'outcome': 'duplicate',
        'asset': <Object?, Object?>{1: 'value'},
      },
      for (final missingKey in const [
        'secure_url',
        'width',
        'height',
        'mime_type',
        'duration_seconds',
      ])
        <String, Object?>{
          'outcome': 'duplicate',
          'asset': <String, Object?>{
            'secure_url': 'https://example.com/image.jpg',
            'width': 100,
            'height': 100,
            'mime_type': null,
            'duration_seconds': null,
          }..remove(missingKey),
        },
      <String, Object?>{'outcome': 'duplicate', 'asset': 'not-a-map'},
      <String, Object?>{
        'outcome': 'duplicate',
        'asset': <String, Object?>{
          'secure_url': 'https://example.com/image.jpg',
          'width': '100',
          'height': 100,
          'mime_type': null,
          'duration_seconds': null,
        },
      },
      <String, Object?>{
        'outcome': 'duplicate',
        'asset': <String, Object?>{
          'secure_url': 1,
          'width': 100,
          'height': 100,
          'mime_type': null,
          'duration_seconds': null,
        },
      },
      <String, Object?>{
        'outcome': 'duplicate',
        'asset': <String, Object?>{
          'secure_url': 'https://example.com/image.jpg',
          'width': 100,
          'height': '100',
          'mime_type': null,
          'duration_seconds': null,
        },
      },
      <String, Object?>{
        'outcome': 'duplicate',
        'asset': <String, Object?>{
          'secure_url': 'https://example.com/image.jpg',
          'width': 100,
          'height': 100,
          'mime_type': 1,
          'duration_seconds': null,
        },
      },
      <String, Object?>{
        'outcome': 'duplicate',
        'asset': <String, Object?>{
          'secure_url': 'https://example.com/image.jpg',
          'width': 100,
          'height': 100,
          'mime_type': null,
          'duration_seconds': 1,
        },
      },
    ];

    for (final response in invalidResponses) {
      expect(
        () => SupabaseCloudinaryUploadPreparationClient.parseResponseForTesting(
          response,
          publicId,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
