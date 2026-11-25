import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart'
    hide DefaultCacheManager;
import 'package:cached_network_image_ce/src/cache/default_cache_manager.dart';
import 'package:http/http.dart' as http;

/// Instruments the installed manager without replacing its disk/expiry policy.
class RecordingImageCacheManager extends DefaultCacheManager {
  RecordingImageCacheManager(Directory directory, {required http.Client client})
    : super(
        httpClientFactory: () => client,
        cacheDirectoryProvider: () async => directory,
        metadataDirectoryProvider: () async => directory,
      );

  final reads = <({String url, String? key})>[];

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    reads.add((url: url, key: key));
    return super.getFileStream(
      url,
      key: key,
      headers: headers,
      withProgress: withProgress,
    );
  }
}
