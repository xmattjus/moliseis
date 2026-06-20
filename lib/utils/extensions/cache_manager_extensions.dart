import 'dart:io' show File;

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager, FileInfo;

extension CacheManagerExtensions on CacheManager {
  Future<File> getSingleFile(String url, {Map<String, String>? headers}) async {
    await for (final response in getFileStream(url, headers: headers)) {
      if (response is FileInfo) {
        return response.file;
      }
    }
    throw Exception('Failed to get file from cache: $url');
  }
}
