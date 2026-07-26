import 'dart:io' show HttpClient;

import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_duplicate_detector.dart';

import '../../../../support/fake_cloudinary_server.dart';

void main() {
  group('CloudinaryDuplicateDetector', () {
    late FakeCloudinaryServer server;
    late HttpClient httpClient;
    late CloudinaryDuplicateDetector detector;

    setUp(() async {
      server = FakeCloudinaryServer();
      await server.start();
      httpClient = HttpClient();
      detector = CloudinaryDuplicateDetector(
        httpClient: httpClient,
        cloudName: server.cloudName,
        apiKey: server.apiKey,
        apiSecret: server.apiSecret,
        baseUrl: server.baseUri.toString(),
      );
    });

    tearDown(() async {
      // Closing the client terminates any idle sockets left open by requests
      // and avoids HttpClient resource-leak warnings.
      httpClient.close(force: true);
      await server.stop();
    });

    test('returns existing secure_url when asset exists', () async {
      const publicId = 'content_submissions/abc';
      const secureUrl = 'https://example.com/existing.jpg';
      server.addExistingAsset(publicId, secureUrl);

      final result = await detector.checkExists(publicId);

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull()?.secureUrl, secureUrl);
      expect(server.requests, hasLength(1));
      expect(server.requests.single.method, 'GET');
      expect(
        server.requests.single.path,
        '/v1_1/${server.cloudName}/resources/image/upload/$publicId',
      );
    });

    test('returns null when asset does not exist', () async {
      const publicId = 'content_submissions/new';

      final result = await detector.checkExists(publicId);

      expect(result.isSuccess, isTrue);
      expect(result.getOrNull(), isNull);
    });

    test('returns error when Admin API returns non-200/404', () async {
      const publicId = 'content_submissions/error';
      server
        ..addExistingAsset(publicId, 'https://x.com/x.jpg')
        ..setAdminError(status: 500, body: 'Internal Server Error');

      final result = await detector.checkExists(publicId);

      expect(result.isError, isTrue);
    });

    test('returns error on unauthorized Admin API response', () async {
      const publicId = 'content_submissions/secret';
      server.addExistingAsset(publicId, 'https://x.com/x.jpg');

      final badHttpClient = HttpClient();
      addTearDown(() => badHttpClient.close(force: true));
      final badDetector = CloudinaryDuplicateDetector(
        httpClient: badHttpClient,
        cloudName: server.cloudName,
        apiKey: 'wrong_key',
        apiSecret: server.apiSecret,
        baseUrl: server.baseUri.toString(),
      );

      final result = await badDetector.checkExists(publicId);

      expect(result.isError, isTrue);
    });
  });
}
