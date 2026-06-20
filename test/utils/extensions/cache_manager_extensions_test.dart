import 'package:cached_network_image_ce/cached_network_image.dart'
    show DownloadProgress, FileInfo, FileSource;
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/extensions/cache_manager_extensions.dart';

import '../../support/fake_cache_manager.dart';

void main() {
  group('DefaultCacheManagerExtensions.getSingleFile', () {
    FakeCacheManager? cacheManager;
    const testUrl = 'https://example.com/image.jpg';

    tearDown(() async {
      await cacheManager?.dispose();
      cacheManager = null;
    });

    test('returns file when FileInfo is emitted', () async {
      final fileSystem = MemoryFileSystem();
      final testFile = fileSystem.file('/test.jpg');

      cacheManager = FakeCacheManager(
        streamFactory: () => Stream.value(
          FileInfo(
            testFile,
            FileSource.Cache,
            DateTime.now().add(const Duration(days: 1)),
            testUrl,
          ),
        ),
      );

      final file = await cacheManager!.getSingleFile(testUrl);

      expect(file.path, '/test.jpg');
    });

    test(
      'returns file when DownloadProgress events precede FileInfo',
      () async {
        final fileSystem = MemoryFileSystem();
        final testFile = fileSystem.file('/test.jpg');

        cacheManager = FakeCacheManager(
          streamFactory: () => Stream.fromIterable([
            const DownloadProgress(testUrl, 1000, 100),
            const DownloadProgress(testUrl, 1000, 500),
            const DownloadProgress(testUrl, 1000, 1000),
            FileInfo(
              testFile,
              FileSource.Online,
              DateTime.now().add(const Duration(days: 1)),
              testUrl,
            ),
          ]),
        );

        final file = await cacheManager!.getSingleFile(testUrl);

        expect(file.path, '/test.jpg');
      },
    );

    test(
      'throws when stream closes without emitting FileInfo',
      () async {
        cacheManager = FakeCacheManager(
          streamFactory: () => Stream.fromIterable([
            const DownloadProgress(testUrl, 1000, 100),
            const DownloadProgress(testUrl, 1000, 500),
            const DownloadProgress(testUrl, 1000, 1000),
          ]),
        );

        await expectLater(
          cacheManager!.getSingleFile(testUrl),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to get file from cache'),
            ),
          ),
        );
      },
    );

    test('propagates error from stream', () async {
      cacheManager = FakeCacheManager(
        streamFactory: () => Stream.error(Exception('Network error')),
      );

      await expectLater(
        cacheManager!.getSingleFile(testUrl),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Network error'),
          ),
        ),
      );
    });
  });
}
