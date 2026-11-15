import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/media/image_error_placeholder.dart';
import 'package:moliseis/ui/post/widgets/components/post_media_slideshow.dart';

import '../../../../support/network_image_harness.dart';
import '../../../../support/post_media_slideshow_harness.dart';
import '../../../../support/test_image_files.dart';

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  for (final decoded in [false, true]) {
    testWidgets(
      '${decoded ? 'evicted decoded' : 'failed'} B remount rejects stale '
      'readiness until its new request settles',
      (tester) async {
        final files = TestImageFiles.create();
        addTearDown(files.dispose);
        final manager = ControlledImageCacheManager();
        final fixture = PostMediaSlideshowHarness(
          media: [slideshowMedia(1), slideshowMedia(2), slideshowMedia(3)],
          cacheManager: manager,
        );
        addTearDown(fixture.dispose);
        await fixture.pump(tester);
        final controller = fixture.controller(tester)..jumpToPage(1);
        await tester.pump();
        await tester.pump();
        final obsolete = fixture.image(tester, 2).onImageLoading!;
        final firstRequest = manager.requests.lastIndexWhere(
          (r) => r.url == slideshowMedia(2).url,
        );
        expect(firstRequest, greaterThanOrEqualTo(0));
        if (decoded) {
          await completeSlideshowImage(
            tester,
            manager,
            firstRequest,
            files.createSizedPng(64, 64).readAsBytesSync(),
          );
        } else {
          manager.fail(
            firstRequest,
            StateError('controlled acquisition failure'),
          );
          await tester.pump();
          await tester.pump();
          await tester.pump();
          expect(find.byType(ImageErrorPlaceholder), findsOneWidget);
        }
        expect(fixture.controlsEnabled(tester), isTrue);
        controller.jumpToPage(0);
        await tester.pump();
        await tester.pump();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is AppNetworkImage &&
                widget.url == slideshowMedia(2).url,
          ),
          findsNothing,
        );
        if (decoded) {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        }
        controller.jumpToPage(1);
        await tester.pump();
        await tester.pump();
        final newRequest = manager.requests.lastIndexWhere(
          (r) => r.url == slideshowMedia(2).url,
        );
        expect(newRequest, greaterThan(firstRequest));
        expect(fixture.controlsEnabled(tester), isFalse);
        obsolete(false);
        await tester.pump();
        await tester.pump();
        expect(fixture.controlsEnabled(tester), isFalse);
        manager.fail(newRequest, StateError('new handled failure'));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(fixture.controlsEnabled(tester), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        obsolete(false);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'actual completion cannot restart autoplay during awaited gallery, '
    'return resumes',
    (tester) async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final manager = ControlledImageCacheManager();
      final fixture = PostMediaSlideshowHarness(
        media: [slideshowMedia(1), slideshowMedia(2)],
        cacheManager: manager,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      final controller = fixture.controller(tester);
      await tester.tapAt(tester.getCenter(find.byType(PostMediaSlideshow)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Open gallery'), findsOneWidget);
      final requestIndex = manager.requests.indexWhere(
        (r) => r.url == slideshowMedia(1).url,
      );
      await completeSlideshowImage(
        tester,
        manager,
        requestIndex,
        files.createSizedPng(64, 64).readAsBytesSync(),
      );
      fixture.rebuild();
      await tester.pump(const Duration(seconds: 6));
      expect(controller.page, 0);
      fixture.router.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 2));
      expect(controller.page, closeTo(1, 0.01));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retained decoded B remount admits synchronous cached success', (
    tester,
  ) async {
    final files = TestImageFiles.create();
    addTearDown(files.dispose);
    final manager = ControlledImageCacheManager();
    final fixture = PostMediaSlideshowHarness(
      media: [slideshowMedia(1), slideshowMedia(2)],
      cacheManager: manager,
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    final controller = fixture.controller(tester)..jumpToPage(1);
    await tester.pump();
    await tester.pump();
    final request = manager.requests.lastIndexWhere(
      (r) => r.url == slideshowMedia(2).url,
    );
    await completeSlideshowImage(
      tester,
      manager,
      request,
      files.createSizedPng(64, 64).readAsBytesSync(),
    );
    expect(fixture.controlsEnabled(tester), isTrue);
    controller.jumpToPage(0);
    await tester.pump();
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is AppNetworkImage && w.url == slideshowMedia(2).url,
      ),
      findsNothing,
    );
    final reads = manager.requests.length;
    controller.jumpToPage(1);
    await tester.pump();
    await tester.pump();
    expect(manager.requests.length, reads);
    expect(fixture.controlsEnabled(tester), isTrue);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 2));
    expect(controller.page, closeTo(0, 0.01));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate gallery opens share one suspension '
      'and navigation errors release it', (tester) async {
    final fixture = PostMediaSlideshowHarness(
      media: [slideshowMedia(1), slideshowMedia(2)],
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    fixture.image(tester, 1).onImageLoading!(false);
    await tester.pump();
    await tester.pump();
    final first = openSlideshowGallery(tester);
    final duplicate = openSlideshowGallery(tester);
    await duplicate;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Open gallery'), findsOneWidget);
    fixture.router.pop();
    await first;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());

    // The real show() boundary fails without a router; observe its Future.
    await tester.pumpWidget(
      networkImageHarness(
        manager: fixture.cacheManager,
        child: SizedBox(
          width: 600,
          height: 400,
          child: PostMediaSlideshow(
            height: 400,
            media: fixture.media,
            visibilityNotifier: fixture.visibility,
          ),
        ),
      ),
    );
    await expectLater(
      openSlideshowGallery(tester),
      throwsA(isA<FlutterError>()),
    );
    fixture.image(tester, 1).onImageLoading!(false);
    await tester.pump();
    await tester.pump();
    expect(fixture.controlsEnabled(tester), isTrue);
    final page = tester.widget<PageView>(find.byType(PageView)).controller!;
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 2));
    expect(page.page, closeTo(1, 0.01));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'actual image completion after gallery disposal cannot touch a dead owner',
    (tester) async {
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final manager = ControlledImageCacheManager();
      final fixture = PostMediaSlideshowHarness(
        media: [slideshowMedia(1), slideshowMedia(2)],
        cacheManager: manager,
      );
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      final callback = fixture.image(tester, 1).onImageLoading!;
      await tester.tapAt(tester.getCenter(find.byType(PostMediaSlideshow)));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      callback(false);
      manager.fail(0, StateError('late handled failure'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
