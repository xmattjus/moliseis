import 'package:meta/meta.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_options.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_preparation.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_preparation_client.dart';
import 'package:moliseis/domain/models/submission_asset.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseCloudinaryUploadPreparationClient
    implements CloudinaryUploadPreparationClient {
  SupabaseCloudinaryUploadPreparationClient({required SupabaseClient client})
    : _client = client;

  static const _functionName = 'prepare-cloudinary-upload';
  static final _publicIdPattern = RegExp(
    r'^content_submissions/([0-9a-f]{64})$',
  );
  static final _canonicalTimestampPattern = RegExp(r'^(?:0|[1-9][0-9]*)$');
  static const _maximumSafeTimestamp = '9007199254740991';
  final SupabaseClient _client;

  @override
  Future<Result<CloudinaryUploadPreparation>> prepare({
    required String publicId,
    required CloudinaryUploadOptions options,
  }) async {
    final match = _publicIdPattern.firstMatch(publicId);
    if (match == null || options.overwrite) {
      return const Result.error(
        FormatException('Unsupported upload preparation request'),
      );
    }
    try {
      final response = await _client.functions.invoke(
        _functionName,
        body: <String, Object?>{
          'content_sha256': match.group(1),
          'max_width': options.maxWidth,
          'max_height': options.maxHeight,
          'tags': options.tags,
          'context': options.context,
          'overwrite': false,
        },
      );
      return Result.success(parseResponseForTesting(response.data, publicId));
    } on FunctionException catch (error) {
      return Result.error(
        Exception(error.reasonPhrase ?? 'Upload preparation failed'),
      );
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  @visibleForTesting
  static CloudinaryUploadPreparation parseResponseForTesting(
    Object? value,
    String publicId,
  ) {
    final body = _object(value, 'response');
    final outcome = body['outcome'];
    if (outcome == 'authorized') {
      final fields = _stringMap(body['fields'], 'fields');
      const required = {
        'api_key',
        'public_id',
        'timestamp',
        'overwrite',
        'upload_preset',
        'signature',
      };
      const optional = {'transformation', 'tags', 'context'};
      if (!fields.keys.every(
            (key) => required.contains(key) || optional.contains(key),
          ) ||
          !required.every(fields.containsKey) ||
          !fields.values.every((value) => value.isNotEmpty) ||
          fields['public_id'] != publicId ||
          fields['overwrite'] != 'false' ||
          !_isCanonicalSafeTimestamp(fields['timestamp'])) {
        throw const FormatException('authorized fields are invalid');
      }
      return CloudinaryAuthorizedUploadPreparation(fields);
    }
    if (outcome == 'duplicate') {
      final asset = _object(body['asset'], 'asset');
      final secureUrl = asset['secure_url'];
      final width = asset['width'];
      final height = asset['height'];
      const requiredAssetKeys = {
        'secure_url',
        'width',
        'height',
        'mime_type',
        'duration_seconds',
      };
      if (!requiredAssetKeys.every(asset.containsKey) ||
          secureUrl is! String ||
          width is! int ||
          width <= 0 ||
          height is! int ||
          height <= 0 ||
          (asset['mime_type'] != null && asset['mime_type'] is! String) ||
          asset['duration_seconds'] != null) {
        throw const FormatException('duplicate asset is invalid');
      }
      return CloudinaryDuplicateUploadPreparation(
        SubmissionAsset(
          secureUrl: secureUrl,
          width: width,
          height: height,
          mimeType: asset['mime_type'] as String?,
        ),
      );
    }
    throw const FormatException('upload preparation outcome is invalid');
  }

  static Map<String, Object?> _object(Object? value, String name) {
    if (value is! Map) throw FormatException('$name must be an object');
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException('$name must have string keys');
      }
      result[key] = entry.value;
    }
    return result;
  }

  static Map<String, String> _stringMap(Object? value, String name) {
    final map = _object(value, name);
    final result = <String, String>{};
    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is! String) {
        throw FormatException('$name must contain strings');
      }
      result[key] = value;
    }
    return result;
  }

  static bool _isCanonicalSafeTimestamp(String? value) {
    if (value == null || !_canonicalTimestampPattern.hasMatch(value)) {
      return false;
    }
    return value.length < _maximumSafeTimestamp.length ||
        (value.length == _maximumSafeTimestamp.length &&
            value.compareTo(_maximumSafeTimestamp) <= 0);
  }
}
