import 'dart:async';
import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/media/bounded_cover_image.dart';

import '../../../../support/image_decode_support.dart';
import '../../../../support/recording_image_cache_manager.dart';
import '../../../../support/test_image_files.dart';

void main() {
  // Construct real transports before the binding installs its HTTP override.
  final clients = [http.Client(), http.Client()];
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fit and cover preserve actual cold/warm/expired original acquisition',
    () async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final bytes = files.createSizedPng(4000, 3000).readAsBytesSync();
      final freshBytes = files.createSizedPng(3000, 4000).readAsBytesSync();
      var responseBytes = bytes;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final sends = <String>[];
      server.listen((request) async {
        sends.add(request.uri.path);
        request.response.headers
          ..contentType = ContentType('image', 'png')
          ..set(HttpHeaders.cacheControlHeader, 'max-age=3600');
        request.response.add(responseBytes);
        await request.response.close();
      });
      final evidence = <({int concurrentReads, int concurrentHttp})>[];
      for (final cover in [false, true]) {
        final directory = Directory.systemTemp.createTempSync(
          'image-acquisition-',
        );
        final manager = RecordingImageCacheManager(
          directory,
          client: clients[cover ? 1 : 0],
        );
        try {
          responseBytes = bytes;
          final cache = PaintingBinding.instance.imageCache
            ..clear()
            ..clearLiveImages();
          final url =
              'http://${server.address.address}:${server.port}/original.png';
          final source = CachedNetworkImageProvider(url, cacheManager: manager);
          final sized = <int, ImageProvider>{
            for (final target in [432, 864])
              target: cover
                  ? BoundedCoverImage(source, width: target, height: target)
                  : ResizeImage(
                      source,
                      width: target,
                      height: target,
                      policy: ResizeImagePolicy.fit,
                    ),
          };
          var sendsBefore = sends.length;
          final first = await decodeImage(sized[864]!);
          expect((
            first.image.width,
            first.image.height,
          ), cover ? (1152, 864) : (864, 648));
          first.dispose();
          expect(manager.reads, hasLength(1));
          expect(sends.length - sendsBefore, 1);
          final original = await manager.getFileFromCache(url);
          expect(original, isNotNull);
          final originalPath = original!.file.path;
          (await decodeImage(sized[864]!)).dispose();
          expect(manager.reads, hasLength(1));
          (await decodeImage(sized[432]!)).dispose();
          expect(manager.reads, hasLength(2));
          expect(sends.length - sendsBefore, 1);
          expect(
            (await manager.getFileFromCache(url))!.file.path,
            originalPath,
          );
          expect(
            manager.reads.every((r) => r.url == url && r.key == null),
            isTrue,
          );

          cache
            ..clear()
            ..clearLiveImages();
          await manager.emptyCache();
          manager.reads.clear();
          sendsBefore = sends.length;
          final frames = await Future.wait([
            decodeImage(sized[864]!),
            decodeImage(sized[864]!),
            decodeImage(sized[432]!),
          ]);
          for (final frame in frames) {
            frame.dispose();
          }
          evidence.add((
            concurrentReads: manager.reads.length,
            concurrentHttp: sends.length - sendsBefore,
          ));
          expect(manager.reads, hasLength(2));

          // Expire the original without depending on wall-clock waits.
          cache
            ..clear()
            ..clearLiveImages();
          await manager.putFile(
            url,
            bytes,
            maxAge: const Duration(days: -1),
            fileExtension: 'png',
          );
          final expired = await manager.getFileFromCache(
            url,
            ignoreMemCache: true,
          );
          expect(expired!.validTill.isBefore(DateTime.now()), isTrue);
          sendsBefore = sends.length;
          final readsBeforeRefresh = manager.reads.length;
          responseBytes = freshBytes;
          final expectedFreshSize = cover ? (864, 1152) : (648, 864);
          final refreshed = Completer<void>();
          final stream = sized[864]!.resolve(ImageConfiguration.empty);
          final listener = ImageStreamListener(
            (image, _) {
              final size = (image.image.width, image.image.height);
              image.dispose();
              if (size == expectedFreshSize && !refreshed.isCompleted) {
                refreshed.complete();
              }
            },
            onError: (e, s) {
              if (!refreshed.isCompleted) refreshed.completeError(e, s);
            },
          );
          stream.addListener(listener);
          try {
            await refreshed.future.timeout(const Duration(seconds: 10));
          } finally {
            stream.removeListener(listener);
          }
          expect(sends.length - sendsBefore, 1);
          expect(manager.reads.length - readsBeforeRefresh, 1);
          debugPrint(
            '${cover ? 'cover' : 'fit'} concurrent=${evidence.last}, '
            'expired HTTP=1',
          );
        } finally {
          PaintingBinding.instance.imageCache
            ..clear()
            ..clearLiveImages();
          await manager.dispose();
          directory.deleteSync(recursive: true);
        }
      }
      expect(evidence[1], evidence[0]);
    },
  );
}
