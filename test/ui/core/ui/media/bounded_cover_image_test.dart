import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/core/ui/media/bounded_cover_image.dart';

import '../../../../support/image_decode_support.dart';
import '../../../../support/test_image_files.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  test('common proportional scale, ceil guards and source/output bounds', () {
    for (final dimensions in [
      (4000, 3000),
      (3000, 4000),
      (4000, 1000),
      (1000, 4000),
      (12000, 1000),
      (1000, 12000),
      (4000, 4000),
      (16, 8),
      (1, 12000),
    ]) {
      for (final dpr in [1.0, 2.0, 2.625, 3.0]) {
        for (final target in [(86, 86), (320, 216), (1000, 1000)]) {
          final w = (target.$1 * dpr).ceil();
          final h = (target.$2 * dpr).ceil();
          final size = boundedCoverSize(
            intrinsicWidth: dimensions.$1,
            intrinsicHeight: dimensions.$2,
            targetWidth: w,
            targetHeight: h,
          );
          expect(size.width, inInclusiveRange(1, dimensions.$1.clamp(1, 1728)));
          expect(
            size.height,
            inInclusiveRange(1, dimensions.$2.clamp(1, 1728)),
          );
          // Ceil error is below one pixel independently on each axis.
          expect(
            math.max(
              (size.width - 1) / dimensions.$1,
              (size.height - 1) / dimensions.$2,
            ),
            lessThanOrEqualTo(
              math.min(size.width / dimensions.$1, size.height / dimensions.$2),
            ),
          );
        }
      }
    }
    expect(
      boundedCoverSize(
        intrinsicWidth: 4000,
        intrinsicHeight: 3000,
        targetWidth: 864,
        targetHeight: 864,
      ),
      (width: 1152, height: 864),
    );
    expect(
      boundedCoverSize(
        intrinsicWidth: 4000,
        intrinsicHeight: 3000,
        targetWidth: 1728,
        targetHeight: 1728,
      ),
      (width: 1728, height: 1296),
    );
    for (final invalid in [
      (0, 1, 1, 1),
      (1, -1, 1, 1),
      (1, 1, 0, 1),
      (1, 1, 1, -1),
    ]) {
      expect(
        () => boundedCoverSize(
          intrinsicWidth: invalid.$1,
          intrinsicHeight: invalid.$2,
          targetWidth: invalid.$3,
          targetHeight: invalid.$4,
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'production file/network keys stay synchronous and isolate requests',
    () async {
      for (final source in <ImageProvider>[
        FileImage(File('identity-only.png')),
        const CachedNetworkImageProvider('https://example.test/image.png'),
      ]) {
        final provider = BoundedCoverImage(source, width: 864, height: 864);
        var synchronous = false;
        final keyFuture = provider.obtainKey(ImageConfiguration.empty);
        final checked = keyFuture.then((_) {
          synchronous = true;
        });
        expect(synchronous, isTrue);
        expect(keyFuture, isA<SynchronousFuture<BoundedCoverImageKey>>());
        await checked;
        final key = await keyFuture;
        expect(
          await BoundedCoverImage(
            source,
            width: 864,
            height: 864,
          ).obtainKey(ImageConfiguration.empty),
          key,
        );
        expect(
          await BoundedCoverImage(
            source,
            width: 258,
            height: 258,
          ).obtainKey(ImageConfiguration.empty),
          isNot(key),
        );
        expect(
          await ResizeImage(
            source,
            width: 864,
            height: 864,
            policy: ResizeImagePolicy.fit,
          ).obtainKey(ImageConfiguration.empty),
          isNot(key),
        );
      }
      final a = await BoundedCoverImage(
        FileImage(File('a')),
        width: 86,
        height: 86,
      ).obtainKey(ImageConfiguration.empty);
      final b = await BoundedCoverImage(
        FileImage(File('b')),
        width: 86,
        height: 86,
      ).obtainKey(ImageConfiguration.empty);
      expect(a, isNot(b));
    },
  );

  test(
    'asynchronous synthetic key failure propagates without hanging',
    () async {
      final error = StateError('synthetic key failure');
      final provider = BoundedCoverImage(
        FailingKeyImageProvider(error),
        width: 86,
        height: 86,
      );
      await expectLater(
        provider
            .obtainKey(ImageConfiguration.empty)
            .timeout(const Duration(seconds: 1)),
        throwsA(same(error)),
      );
      await expectLater(decodeImage(provider), throwsA(same(error)));
      expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
    },
  );

  test(
    'real PNG decodes match proportional targets including both panoramas',
    () async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      for (final dimensions in [
        (4000, 3000),
        (3000, 4000),
        (4000, 1000),
        (1000, 4000),
        (12000, 1000),
        (1000, 12000),
        (4000, 4000),
        (16, 8),
      ]) {
        final source = FileImage(
          files.createSizedPng(dimensions.$1, dimensions.$2),
        );
        for (final target in [86, 172, 226, 258, 864, 1728]) {
          final expected = boundedCoverSize(
            intrinsicWidth: dimensions.$1,
            intrinsicHeight: dimensions.$2,
            targetWidth: target,
            targetHeight: target,
          );
          final image = await decodeImage(
            BoundedCoverImage(source, width: target, height: target),
          );
          expect(
            (image.image.width, image.image.height),
            (expected.width, expected.height),
            reason: '${dimensions.$1}x${dimensions.$2} at $target',
          );
          image.dispose();
        }
      }
    },
  );

  test('EXIF orientation is applied before target sizing', () async {
    final source = CountingImageProvider(
      FileImage(File('test/fixtures/images/orientation_6.jpg')),
    );
    final image = await decodeImage(
      BoundedCoverImage(source, width: 86, height: 86),
    );
    expect((image.image.width, image.image.height), (86, 115));
    image.dispose();
  });

  test(
    'nonsquare targets and equal bounded outputs retain distinct keys',
    () async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final ordinary = FileImage(files.createSizedPng(4000, 3000));
      final frame = await decodeImage(
        BoundedCoverImage(ordinary, width: 320, height: 216),
      );
      expect((frame.image.width, frame.image.height), (320, 240));
      frame.dispose();
      final panorama = CountingImageProvider(
        FileImage(files.createSizedPng(12000, 1000)),
      );
      for (final target in [258, 864, 258, 864]) {
        final image = await decodeImage(
          BoundedCoverImage(panorama, width: target, height: target),
        );
        expect((image.image.width, image.image.height), (1728, 144));
        image.dispose();
      }
      expect(panorama.decodes, 2);
    },
  );

  test(
    'fit, bounded cover and full resolution have observed buffer sizes',
    () async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      for (final row in [
        (4000, 3000, 864, (864, 648), (1152, 864)),
        (4000, 3000, 1728, (1728, 1296), (1728, 1296)),
        (12000, 1000, 258, (258, 21), (1728, 144)),
        (12000, 1000, 864, (864, 72), (1728, 144)),
        (12000, 1000, 1728, (1728, 144), (1728, 144)),
        (1000, 12000, 258, (21, 258), (144, 1728)),
        (4000, 4000, 1728, (1728, 1728), (1728, 1728)),
        (16, 8, 86, (16, 8), (16, 8)),
      ]) {
        final source = FileImage(files.createSizedPng(row.$1, row.$2));
        final providers = <ImageProvider>[
          ResizeImage(
            source,
            width: row.$3,
            height: row.$3,
            policy: ResizeImagePolicy.fit,
          ),
          BoundedCoverImage(source, width: row.$3, height: row.$3),
          source,
        ];
        final expected = [row.$4, row.$5, (row.$1, row.$2)];
        for (var i = 0; i < providers.length; i++) {
          final frame = await decodeImage(providers[i]);
          expect((frame.image.width, frame.image.height), expected[i]);
          expect(
            frame.image.width * frame.image.height * 4,
            expected[i].$1 * expected[i].$2 * 4,
          );
          frame.dispose();
        }
      }
    },
  );

  test(
    'multiframe codec retains playback and current resize limitation',
    () async {
      final file = File('test/fixtures/images/animated_1800x2.gif');
      final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
      ({int width, int height})? requested;
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (w, h) {
          requested = boundedCoverSize(
            intrinsicWidth: w,
            intrinsicHeight: h,
            targetWidth: 86,
            targetHeight: 86,
          );
          return ui.TargetImageSize(
            width: requested!.width,
            height: requested!.height,
          );
        },
      );
      expect(requested, (width: 1728, height: 2));
      addTearDown(codec.dispose);
      expect(codec.frameCount, 2);
      final first = await codec.getNextFrame();
      final second = await codec.getNextFrame();
      expect((first.image.width, first.image.height), (1800, 2));
      expect(first.duration, const Duration(milliseconds: 100));
      expect(second.duration, const Duration(milliseconds: 100));
      expect(
        (await first.image.toByteData())!.getUint32(0),
        isNot((await second.image.toByteData())!.getUint32(0)),
      );
      first.image.dispose();
      second.image.dispose();
    },
  );

  test(
    'fit/cover order, retained reuse and listener release use real outputs',
    () async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final source = CountingImageProvider(
        FileImage(files.createSizedPng(4000, 3000)),
      );
      final cover = BoundedCoverImage(source, width: 864, height: 864);
      final fit = ResizeImage(
        source,
        width: 864,
        height: 864,
        policy: ResizeImagePolicy.fit,
      );
      for (final order in <List<ImageProvider>>[
        [cover, fit, cover, fit],
        [fit, cover, fit, cover],
      ]) {
        PaintingBinding.instance.imageCache.clear();
        source.decodes = 0;
        for (final provider in order) {
          final image = await decodeImage(provider);
          expect((
            image.image.width,
            image.image.height,
          ), provider is BoundedCoverImage ? (1152, 864) : (864, 648));
          image.dispose();
        }
        expect(source.decodes, 2);
        final cache = PaintingBinding.instance.imageCache;
        expect(cache.currentSize, 2);
        expect(cache.liveImageCount, 0);
        expect(cache.pendingImageCount, 0);
      }
      final image = await decodeImage(source);
      expect((image.image.width, image.image.height), (4000, 3000));
      image.dispose();
    },
  );

  test('decode failure evicts outer key and permits recovery', () async {
    final files = TestImageFiles.create();
    addTearDown(files.dispose);
    final file = files.createSizedPng(400, 300);
    final bytes = file.readAsBytesSync();
    file.writeAsBytesSync([0, 1, 2, 3]);
    final provider = BoundedCoverImage(FileImage(file), width: 86, height: 86);
    final key = await provider.obtainKey(ImageConfiguration.empty);
    await expectLater(decodeImage(provider), throwsA(anything));
    await Future<void>.delayed(Duration.zero);
    expect(
      PaintingBinding.instance.imageCache.statusForKey(key).untracked,
      isTrue,
    );
    file.writeAsBytesSync(bytes);
    final image = await decodeImage(provider);
    expect((image.image.width, image.image.height), (115, 86));
    image.dispose();
    expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
    expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
  });

  test(
    'released panorama and thirty ordinary cohorts keep default cache limits',
    () async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final cache = PaintingBinding.instance.imageCache;
      expect(cache.maximumSizeBytes, 100 << 20);
      expect(cache.maximumSize, 1000);
      for (final cohort in [
        (12000, 1000, 1),
        (12000, 1000, 5),
        (12000, 1000, 10),
        (12000, 1000, 20),
        (4000, 3000, 30),
      ]) {
        final sources = List.generate(
          cohort.$3,
          (_) => CountingImageProvider(
            FileImage(files.createSizedPng(cohort.$1, cohort.$2)),
          ),
        );
        for (final cover in [false, true]) {
          cache.clear();
          for (final source in sources) {
            source.decodes = 0;
          }
          final providers = sources
              .map<ImageProvider>(
                (source) => cover
                    ? BoundedCoverImage(source, width: 864, height: 864)
                    : ResizeImage(
                        source,
                        width: 864,
                        height: 864,
                        policy: ResizeImagePolicy.fit,
                      ),
              )
              .toList();
          for (final provider in providers) {
            final image = await decodeImage(provider);
            expect(
              (image.image.width, image.image.height),
              cohort.$1 == 12000
                  ? (cover ? (1728, 144) : (864, 72))
                  : (cover ? (1152, 864) : (864, 648)),
            );
            image.dispose();
          }
          final retained = cache.currentSize;
          final bytes = cache.currentSizeBytes;
          expect(cache.liveImageCount, 0);
          expect(cache.pendingImageCount, 0);
          final firstPassDecodes = sources.fold<int>(
            0,
            (n, s) => n + s.decodes,
          );
          for (final provider in providers) {
            final image = await decodeImage(provider);
            image.dispose();
          }
          final revisits =
              sources.fold<int>(0, (n, s) => n + s.decodes) - firstPassDecodes;
          // Reproducible cache evidence; not process-memory accounting.
          debugPrint(
            '${cohort.$1}x${cohort.$2} n=${cohort.$3} '
            '${cover ? 'cover' : 'fit'} '
            'retained=$retained bytes=$bytes live=${cache.liveImageCount} '
            'pending=${cache.pendingImageCount} revisitDecodes=$revisits',
          );
          if (cohort.$1 == 12000) {
            expect(retained, cohort.$3);
            expect(revisits, 0);
          }
          if (cohort.$1 == 4000 && !cover) {
            expect(retained, 30);
            expect(revisits, 0);
          }
          if (cohort.$1 == 4000 && cover) {
            expect(retained, 26);
            expect(revisits, 30);
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
