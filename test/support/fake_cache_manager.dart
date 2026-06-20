import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show
        CacheManager,
        DefaultCacheManager,
        FileInfo,
        FileResponse,
        ImageCacheManager;
import 'package:file/file.dart' show File;

/// A lightweight [CacheManager] test double.
///
/// Implements the abstract [CacheManager] and [ImageCacheManager] interfaces
/// directly rather than extending the concrete [DefaultCacheManager]. Because
/// the class no longer inherits from a real implementation, no method can
/// silently fall through to filesystem or Hive I/O: every member not wired up
/// below throws [UnimplementedError] instead of hitting disk.
///
/// Only [getFileStream] and [getImageFile] are wired up, as those are the only
/// methods the current tests exercise. Override the throwing members in a
/// subclass if your test needs them.
class FakeCacheManager implements CacheManager, ImageCacheManager {
  FakeCacheManager({this.streamFactory});

  /// Called by [getFileStream] and, transitively, by [getImageFile].
  ///
  /// Takes no parameters (URL/headers are not forwarded) to keep the API
  /// simple. Override [getFileStream] in a subclass if your test needs
  /// URL-specific behaviour.
  final Stream<FileResponse> Function()? streamFactory;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => streamFactory?.call() ?? const Stream.empty();

  @override
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) {
    assert(
      maxHeight == null && maxWidth == null,
      'FakeDefaultCacheManager does not support image resizing. '
      'Override getImageFile in a subclass if your test needs it.',
    );
    return getFileStream(
      url,
      key: key,
      headers: headers,
      withProgress: withProgress,
    );
  }

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) => Future.error(
    UnimplementedError(
      'FakeDefaultCacheManager.getFileFromCache is not implemented. '
      'Override it in a subclass if your test needs it.',
    ),
  );

  @override
  Future<File> putFile(
    String url,
    List<int> fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) => Future.error(
    UnimplementedError(
      'FakeDefaultCacheManager.putFile is not implemented. '
      'Override it in a subclass if your test needs it.',
    ),
  );

  @override
  Future<void> removeFile(String key) => Future.error(
    UnimplementedError(
      'FakeDefaultCacheManager.removeFile is not implemented. '
      'Override it in a subclass if your test needs it.',
    ),
  );

  @override
  Future<void> emptyCache() => Future.error(
    UnimplementedError(
      'FakeDefaultCacheManager.emptyCache is not implemented. '
      'Override it in a subclass if your test needs it.',
    ),
  );

  @override
  Future<void> dispose() async {}
}
