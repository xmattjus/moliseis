import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/media/image_error_placeholder.dart';

import '../../../../support/image_decode_support.dart';
import '../../../../support/mock_logger.dart';
import '../../../../support/network_image_harness.dart';
import '../../../../support/test_image_files.dart';

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  for (final full in [false, true]) {
    testWidgets('${full ? 'gallery' : 'bounded'} settles errors once '
        'and fences disposed callbacks', (tester) async {
      final manager = ControlledImageCacheManager();
      addTearDown(manager.dispose);
      final states = <bool>[];
      final logger = MockLogger();
      final image = full
          ? AppNetworkImage.fullResolution(
              url: 'https://example.test/private.jpg',
              onImageLoading: states.add,
            )
          : AppNetworkImage(
              url: 'https://example.test/private.jpg',
              width: 86,
              height: 86,
              onImageLoading: states.add,
            );
      await tester.pumpWidget(
        networkImageHarness(manager: manager, logger: logger, child: image),
      );
      expect(states, [true]);
      final stale = tester.widget<Image>(find.byType(Image));
      final cause = TimeoutException('PRIVATE_URL_CANARY');
      manager.fail(0, cause);
      await tester.pumpAndSettle();
      expect(states, [true, false]);
      expect(find.byType(ImageErrorPlaceholder), findsOneWidget);
      expect(logger.calls, hasLength(1));
      expect(logger.calls.single.error, same(cause));
      expect(logger.calls.single.stackTrace, isNotNull);
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Immagine non disponibile'), findsOneWidget);
      semantics.dispose();
      await tester.pumpWidget(
        networkImageHarness(manager: manager, logger: logger, child: image),
      );
      await tester.pump();
      expect(states, [true, false]);
      expect(logger.calls, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      stale.frameBuilder!(
        tester.element(find.byType(SizedBox).first),
        const SizedBox(),
        0,
        false,
      );
      stale.errorBuilder!(
        tester.element(find.byType(SizedBox).first),
        Exception('late'),
        StackTrace.current,
      );
      expect(states, [true, false]);
      expect(logger.calls, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending replacement after a real failure does not inherit '
      'the failed request presentation or readiness', (tester) async {
    final manager = ControlledImageCacheManager();
    addTearDown(manager.dispose);
    final files = TestImageFiles.create();
    addTearDown(files.dispose);
    final bytes = files.createSizedPng(400, 300).readAsBytesSync();
    final logger = MockLogger();
    final states = <bool>[];
    Future<void> show(String url) => tester.pumpWidget(
      networkImageHarness(
        manager: manager,
        logger: logger,
        child: AppNetworkImage(
          url: url,
          width: 86,
          height: 86,
          onImageLoading: states.add,
        ),
      ),
    );

    await show('https://example.test/a.png');
    final state = tester.state(find.byType(AppNetworkImage));
    manager.fail(0, Exception('a failed'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageErrorPlaceholder), findsOneWidget);
    expect(states, [true, false]);
    expect(logger.calls, hasLength(1));

    await show('https://example.test/b.png');
    await tester.pump();
    expect(tester.state(find.byType(AppNetworkImage)), same(state));
    expect(manager.requests.map((r) => r.url).last, endsWith('/b.png'));
    expect(find.byType(ImageErrorPlaceholder), findsNothing);
    expect(states, [true, false, true]);
    expect(logger.calls, hasLength(1));

    manager.complete(1, bytes);
    await tester.pump();
    await tester.runAsync(() async {
      final frame = await decodeImage(
        tester.widget<Image>(find.byType(Image)).image,
      );
      frame.dispose();
    });
    await tester.pumpAndSettle();
    expect(find.byType(ImageErrorPlaceholder), findsNothing);
    final raw = tester.widget<RawImage>(find.byType(RawImage));
    expect(raw.image, isNotNull);
    expect(states, [true, false, true, false]);
    expect(logger.calls, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('target and fit replacement revokes old publications; '
      'unchanged builds dedup', (tester) async {
    final manager = ControlledImageCacheManager();
    addTearDown(manager.dispose);
    final files = TestImageFiles.create();
    addTearDown(files.dispose);
    final bytes = files.createSizedPng(4000, 3000).readAsBytesSync();
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    final states = <bool>[];
    for (final entry in [
      (86.0, BoxFit.cover),
      (300.0, BoxFit.cover),
      (300.0, BoxFit.contain),
    ]) {
      final previous = find.byType(Image).evaluate().isEmpty
          ? null
          : tester.widget<Image>(find.byType(Image));
      await tester.pumpWidget(
        networkImageHarness(
          manager: manager,
          child: AppNetworkImage(
            url: 'https://example.test/source.png',
            width: entry.$1,
            height: entry.$1,
            fit: entry.$2,
            onImageLoading: states.add,
          ),
        ),
      );
      expect(states.last, isTrue);
      final count = states.length;
      if (previous != null) {
        previous.frameBuilder!(
          tester.element(find.byType(Image)),
          const SizedBox(),
          0,
          false,
        );
        expect(states.length, count);
      }
      manager.complete(manager.requests.length - 1, bytes);
      await tester.pump();
      await tester.runAsync(() async {
        final frame = await decodeImage(
          tester.widget<Image>(find.byType(Image)).image,
        );
        frame.dispose();
      });
      await tester.pumpAndSettle();
      expect(states.last, isFalse);
      final raw = tester.widget<RawImage>(find.byType(RawImage));
      final bucket = entry.$1 == 86 ? 216 : 720;
      expect(
        raw.image!.width,
        entry.$2 == BoxFit.cover ? (bucket * 4 / 3).ceil() : bucket,
      );
      expect(
        raw.image!.height,
        entry.$2 == BoxFit.cover ? bucket : (bucket * 3 / 4).round(),
      );
      final terminalCount = states.length;
      await tester.pumpWidget(
        networkImageHarness(
          manager: manager,
          child: AppNetworkImage(
            url: 'https://example.test/source.png',
            width: entry.$1,
            height: entry.$1,
            fit: entry.$2,
            onImageLoading: states.add,
          ),
        ),
      );
      await tester.pump();
      expect(states.length, terminalCount);
    }
    expect(manager.requests, hasLength(3));
    expect(
      manager.requests.every(
        (r) => r.url == 'https://example.test/source.png' && r.key == null,
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    final freshStates = <bool>[];
    await tester.pumpWidget(
      networkImageHarness(
        manager: manager,
        child: AppNetworkImage(
          url: 'https://example.test/source.png',
          width: 300,
          height: 300,
          fit: BoxFit.contain,
          onImageLoading: freshStates.add,
        ),
      ),
    );
    expect(freshStates, [false]);
    expect(manager.requests, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source replacement and disposal reject actual late acquisitions',
    (tester) async {
      final manager = ControlledImageCacheManager();
      addTearDown(manager.dispose);
      final states = <bool>[];
      for (final source in ['a', 'b']) {
        await tester.pumpWidget(
          networkImageHarness(
            manager: manager,
            child: AppNetworkImage(
              url: 'https://example.test/$source.png',
              width: 86,
              height: 86,
              onImageLoading: states.add,
            ),
          ),
        );
      }
      expect(states, [true, true]);
      manager.fail(0, Exception('obsolete a'));
      await tester.pumpAndSettle();
      expect(states, [true, true]);
      await tester.pumpWidget(const SizedBox.shrink());
      manager.fail(1, Exception('disposed b'));
      await tester.pumpAndSettle();
      expect(states, [true, true]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gallery remains full resolution; oversized bucket keeps 1728 square',
    (tester) async {
      final manager = ControlledImageCacheManager();
      addTearDown(manager.dispose);
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final bytes = files.createSizedPng(2400, 2400).readAsBytesSync();
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final full in [false, true]) {
        final states = <bool>[];
        await tester.pumpWidget(
          networkImageHarness(
            manager: manager,
            child: full
                ? AppNetworkImage.fullResolution(
                    url: 'https://example.test/large.png',
                    fit: BoxFit.contain,
                    onImageLoading: states.add,
                  )
                : AppNetworkImage(
                    url: 'https://example.test/large.png',
                    width: 1000,
                    height: 1000,
                    onImageLoading: states.add,
                  ),
          ),
        );
        manager.complete(manager.requests.length - 1, bytes);
        await tester.pump();
        await tester.runAsync(() async {
          final frame = await decodeImage(
            tester.widget<Image>(find.byType(Image)).image,
          );
          frame.dispose();
        });
        await tester.pumpAndSettle();
        final raw = tester.widget<RawImage>(find.byType(RawImage));
        expect(raw.image!.width, full ? 2400 : 1728);
        expect(raw.image!.height, full ? 2400 : 1728);
        expect(states.last, isFalse);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
