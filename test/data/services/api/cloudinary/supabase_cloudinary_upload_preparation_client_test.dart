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
        'secure_url': 'https://example.com/image.jpg',
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
              'secure_url': 'https://example.com/image.jpg',
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
