import 'dart:async' show Completer;
import 'dart:collection';

import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_options.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_preparation.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_preparation_client.dart';
import 'package:moliseis/utils/result.dart';

final class FakeCloudinaryUploadPreparationClient
    implements CloudinaryUploadPreparationClient {
  final Queue<Result<CloudinaryUploadPreparation>> _results = Queue();
  final Queue<Completer<Result<CloudinaryUploadPreparation>>> _pending =
      Queue();
  final _preparationStarted = Completer<void>();
  final calls = <({String publicId, CloudinaryUploadOptions options})>[];

  /// Completes when [prepare] first receives a request.
  Future<void> get whenPreparationStarted => _preparationStarted.future;

  void enqueue(Result<CloudinaryUploadPreparation> result) =>
      _results.add(result);

  /// Makes the next preparation call wait until the returned completer ends.
  Completer<Result<CloudinaryUploadPreparation>> makeNextPreparationPending() {
    final completer = Completer<Result<CloudinaryUploadPreparation>>();
    _pending.add(completer);
    return completer;
  }

  @override
  Future<Result<CloudinaryUploadPreparation>> prepare({
    required String publicId,
    required CloudinaryUploadOptions options,
  }) async {
    calls.add((publicId: publicId, options: options));
    if (!_preparationStarted.isCompleted) _preparationStarted.complete();
    if (_pending.isNotEmpty) return _pending.removeFirst().future;
    if (_results.isEmpty) {
      return Result.success(
        CloudinaryAuthorizedUploadPreparation({
          'api_key': 'test-key',
          'public_id': publicId,
          'timestamp': '1',
          'overwrite': 'false',
          'upload_preset': 'test-preset',
          'signature': 'test-signature',
        }),
      );
    }
    return _results.removeFirst();
  }
}
