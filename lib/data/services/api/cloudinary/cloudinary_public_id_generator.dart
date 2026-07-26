import 'dart:io' show File;

import 'package:crypto/crypto.dart' show sha256;

/// Generates deterministic Cloudinary public IDs for user-contributed images.
class CloudinaryPublicIdGenerator {
  /// Prefix applied to every generated public ID.
  static const String prefix = 'content_submissions';

  /// Returns `content_submissions/<sha256>` for [file].
  Future<String> generate(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return '$prefix/$digest';
  }
}
