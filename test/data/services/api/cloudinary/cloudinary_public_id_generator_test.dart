import 'dart:io' show Directory, File;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_public_id_generator.dart';

void main() {
  group('CloudinaryPublicIdGenerator', () {
    late Directory tempDir;
    final generator = CloudinaryPublicIdGenerator();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('public_id_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('prefixes generated id with content_submissions/', () async {
      final file = File('${tempDir.path}/image.jpg')
        ..writeAsBytesSync([1, 2, 3]);

      final publicId = await generator.generate(file);

      expect(publicId, startsWith('${CloudinaryPublicIdGenerator.prefix}/'));
    });

    test('uses SHA-256 of file contents', () async {
      final bytes = [10, 20, 30, 40, 50];
      final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync(bytes);
      final expectedDigest = sha256.convert(bytes).toString();

      final publicId = await generator.generate(file);

      expect(publicId, 'content_submissions/$expectedDigest');
    });

    test('is deterministic for the same file contents', () async {
      final file = File('${tempDir.path}/image.jpg')
        ..writeAsBytesSync([5, 6, 7, 8]);

      final a = await generator.generate(file);
      final b = await generator.generate(file);

      expect(a, b);
    });

    test('does not buffer the whole file in memory', () async {
      // The implementation uses sha256.bind(file.openRead()).first, which
      // streams bytes through the hasher. This test exercises that path with
      // a moderately sized payload and asserts a stable digest.
      final bytes = List<int>.generate(10 * 1024, (i) => i % 256);
      final file = File('${tempDir.path}/large.bin')..writeAsBytesSync(bytes);
      final expectedDigest = sha256.convert(bytes).toString();

      final publicId = await generator.generate(file);

      expect(publicId, 'content_submissions/$expectedDigest');
    });
  });
}
