import 'dart:convert' show base64Encode, jsonDecode, utf8;
import 'dart:io' show HttpClient, HttpClientResponse;

import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_cancellation_token.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/result.dart';

/// Checks whether a Cloudinary asset already exists via the Admin API.
class CloudinaryDuplicateDetector {
  /// Creates a duplicate detector.
  CloudinaryDuplicateDetector({
    required HttpClient httpClient,
    required String cloudName,
    required String apiKey,
    required String apiSecret,
    String? baseUrl,
  }) : _httpClient = httpClient,
       _cloudName = cloudName,
       _apiKey = apiKey,
       _apiSecret = apiSecret,
       _baseUrl = baseUrl;

  final HttpClient _httpClient;
  final String _cloudName;
  final String _apiKey;
  final String _apiSecret;
  final String? _baseUrl;

  /// Returns the existing asset URL if [publicId] exists, otherwise `null`.
  ///
  /// When [token] is provided, the underlying HTTP request is aborted if the
  /// caller cancels the upload before the Admin API responds.
  Future<Result<SubmissionAsset?>> checkExists(
    String publicId, {
    CloudinaryUploadCancellationToken? token,
  }) async {
    final baseUri = Uri.parse(_baseUrl ?? 'https://api.cloudinary.com');
    final uri = baseUri.replace(
      path: '/v1_1/$_cloudName/resources/image/upload/$publicId',
    );

    final request = await _httpClient.getUrl(uri);
    token?.attach(request);
    final credentials = base64Encode(utf8.encode('$_apiKey:$_apiSecret'));
    request.headers.add('Authorization', 'Basic $credentials');

    late final HttpClientResponse response;
    try {
      response = await request.close();
    } on Exception catch (exception) {
      return Result.error(
        _DuplicateLookupException('Network error: $exception'),
      );
    }

    if (response.statusCode == 404) {
      await response.drain<void>();
      return const Result.success(null);
    }

    if (response.statusCode == 200) {
      try {
        final body = await response.toList();
        final bytes = body.expand((chunk) => chunk).toList();
        final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final secureUrl = json['secure_url'] as String?;
        final width = json['width'] as int?;
        final height = json['height'] as int?;
        if (secureUrl == null) {
          return const Result.error(
            _DuplicateLookupException(
              'Admin API returned 200 but no secure_url',
            ),
          );
        }
        if (width == null || height == null) {
          return const Result.error(
            _DuplicateLookupException(
              'Admin API returned 200 but no dimensions',
            ),
          );
        }
        final submissionAsset = SubmissionAsset(
          secureUrl: secureUrl,
          width: width,
          height: height,
        );
        return Result.success(submissionAsset);
      } on Exception catch (exception, stackTrace) {
        return Result.error(
          _DuplicateLookupException(
            'Failed to parse Admin API response: $exception',
            stackTrace,
          ),
        );
      }
    }

    await response.drain<void>();
    return Result.error(
      _DuplicateLookupException(
        'Admin API returned status ${response.statusCode}',
      ),
    );
  }
}

class _DuplicateLookupException implements Exception {
  const _DuplicateLookupException(this.message, [this.stackTrace]);

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => '_DuplicateLookupException: $message';
}
