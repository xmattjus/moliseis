import 'dart:convert' show utf8;
import 'dart:io' show Directory, File;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_multipart_writer.dart';

void main() {
  group('CloudinaryMultipartWriter', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('multipart_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('computeTotalLength equals consumed byte count of write()', () async {
      final file = File('${tempDir.path}/image.jpg')
        ..writeAsBytesSync([1, 2, 3, 4, 5]);
      final writer = CloudinaryMultipartWriter(
        file: file,
        fields: const {
          'public_id': 'content_submissions/abc123',
          'timestamp': '1234567890',
        },
        fileName: 'image.jpg',
      );

      final expectedLength = await writer.computeTotalLength();
      final chunks = await writer.write().toList();
      final totalBytes = chunks.fold<int>(0, (sum, c) => sum + c.length);

      expect(totalBytes, expectedLength);
    });

    test('emits correct Content-Type with boundary', () {
      final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([0]);
      final writer = CloudinaryMultipartWriter(
        file: file,
        fields: const {},
        fileName: 'image.jpg',
      );

      expect(
        writer.contentType,
        'multipart/form-data; boundary=${writer.boundary}',
      );
      expect(writer.boundary, startsWith('----DartFormBoundary'));
    });

    test(
      'escapes double-quotes in filename within Content-Disposition',
      () async {
        final file = File('${tempDir.path}/image.jpg')..writeAsBytesSync([1]);
        final writer = CloudinaryMultipartWriter(
          file: file,
          fields: const {},
          fileName: 'evil"name.jpg',
        );

        final chunks = await writer.write().toList();
        final body = utf8.decode(
          chunks.expand((c) => c).toList(),
          allowMalformed: true,
        );

        // The raw double-quote must be escaped to \" in the header value.
        expect(body, contains(r'filename="evil\"name.jpg"'));
        expect(body, isNot(contains('filename="evil"name.jpg"')));
      },
    );

    test('encodes text fields and file content correctly', () async {
      final fileBytes = [10, 20, 30, 40];
      final file = File('${tempDir.path}/upload.png')
        ..writeAsBytesSync(fileBytes);
      final writer = CloudinaryMultipartWriter(
        file: file,
        fields: const {
          'public_id': 'content_submissions/abc',
          'signature': 'deadbeef',
        },
        fileName: 'upload.png',
      );

      final chunks = await writer.write().toList();
      final body = utf8.decode(
        chunks.expand((c) => c).toList(),
        allowMalformed: true,
      );

      expect(body, contains('--${writer.boundary}'));
      expect(body, contains('--${writer.boundary}--\r\n'));
      expect(
        body,
        contains('Content-Disposition: form-data; name="public_id"'),
      );
      expect(body, contains('content_submissions/abc'));
      expect(
        body,
        contains('Content-Disposition: form-data; name="signature"'),
      );
      expect(body, contains('deadbeef'));
      expect(
        body,
        contains(
          'Content-Disposition: form-data; name="file"; '
          'filename="upload.png"',
        ),
      );
      expect(body, contains('Content-Type: application/octet-stream'));
    });

    test(
      'each section except the last is terminated with a boundary prefix',
      () async {
        final file = File('${tempDir.path}/x.jpg')..writeAsBytesSync([1]);
        final writer = CloudinaryMultipartWriter(
          file: file,
          fields: const {'a': '1', 'b': '2'},
          fileName: 'x.jpg',
        );

        final chunks = await writer.write().toList();
        final bodyBytes = chunks.expand((c) => c).toList();
        final body = utf8.decode(bodyBytes, allowMalformed: true);

        final boundary = writer.boundary;
        final sectionStarts = '--$boundary'.allMatches(body).length;
        final finalBoundaryCount = '--$boundary--'.allMatches(body).length;

        expect(sectionStarts, 4); // 2 fields + 1 file + 1 final marker
        expect(finalBoundaryCount, 1);
      },
    );
  });
}
