import 'dart:async' show unawaited;

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/media/image_error_placeholder.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
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

  // Each step replaces one input of the active page's effective request and
  // triggers only the rebuilds that change itself would cause.
  final replacements =
      <String, List<void Function(WidgetTester, PostMediaSlideshowHarness)>>{
        'bucket': [
          (_, fixture) => fixture
            ..width = 300
            ..rebuild(),
          (_, fixture) => fixture
            ..width = 450
            ..rebuild(),
        ],
        // Only MediaQuery dependents rebuild; the slideshow's parent does not.
        'DPR': [
          (tester, _) => tester.view.devicePixelRatio = 1,
          (tester, _) => tester.view.devicePixelRatio = 2,
        ],
        // Decoded identity is URL-based, so a retained decode would be a valid
        // synchronous hit; clear it to make the new manager's request pending.
        // Provider reads do not subscribe, so a parent rebuild applies it.
        'cache manager': [
          for (var i = 0; i < 2; i++)
            (_, fixture) {
              PaintingBinding.instance.imageCache
                ..clear()
                ..clearLiveImages();
              fixture
                ..cacheManager = ControlledImageCacheManager()
                ..rebuild();
            },
        ],
      };
  for (final MapEntry(key: input, value: steps) in replacements.entries) {
    testWidgets('$input replacement invalidates readiness in its first frame; '
        'late obsolete completion cannot admit the pending request', (
      tester,
    ) async {
      addTearDown(tester.view.resetDevicePixelRatio);
      final files = TestImageFiles.create();
      addTearDown(files.dispose);
      final bytes = files.createSizedPng(64, 64).readAsBytesSync();
      final fixture = PostMediaSlideshowHarness(
        media: [slideshowMedia(1), slideshowMedia(2)],
        cacheManager: ControlledImageCacheManager(),
      );
      final managers = <ControlledImageCacheManager>[];
      addTearDown(() async {
        await fixture.dispose();
        for (final manager in managers) {
          await manager.dispose();
        }
      });
      ControlledImageCacheManager current() =>
          fixture.cacheManager as ControlledImageCacheManager;
      int request() => current().lastRequestFor(slideshowMedia(1).url);
      Future<void> replace(int step) async {
        final previous = current();
        steps[step](tester, fixture);
        // Exactly one frame: controls must already reflect the new request.
        if (identical(previous, fixture.cacheManager)) {
          await tester.pump();
        } else {
          managers.add(previous);
          await fixture.pump(tester);
        }
      }

      await fixture.pump(tester);
      await completeSlideshowImage(tester, current(), request(), bytes);
      expect(fixture.controlsEnabled(tester), isTrue);

      // Old terminal readiness must not survive into the new request.
      await replace(0);
      expect(fixture.controlsEnabled(tester), isFalse);
      final pending = request();
      expect(pending, greaterThanOrEqualTo(0));
      final pendingManager = current();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isFalse);

      // Keep the original stream observable even if replacement evicts it.
      final obsoleteStream = slideshowImageStream(
        tester,
        pendingManager.requests[pending].url,
      );
      final handle = obsoleteStream.completer!.keepAlive();
      addTearDown(handle.dispose);

      // Replace again while that request is pending, then complete it late.
      await replace(1);
      expect(fixture.controlsEnabled(tester), isFalse);
      final effective = request();
      expect(
        identical(pendingManager, current()) ? effective : pending + 1,
        greaterThan(pending),
      );
      await completeSlideshowImage(
        tester,
        pendingManager,
        pending,
        bytes,
        stream: obsoleteStream,
      );
      expect(fixture.controlsEnabled(tester), isFalse);
      await tester.pump(const Duration(seconds: 6));
      expect(fixture.controller(tester).page, 0);

      await completeSlideshowImage(tester, current(), effective, bytes);
      expect(fixture.controlsEnabled(tester), isTrue);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 2));
      expect(fixture.controller(tester).page, closeTo(1, 0.01));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'retained bucket is synchronously admissible; unchanged parent rebuilds '
    'keep readiness without new requests or extra frames',
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
      await completeSlideshowImage(
        tester,
        manager,
        0,
        files.createSizedPng(64, 64).readAsBytesSync(),
      );
      // User pause stops the ticker so scheduled frames are observable.
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(fixture.controlsEnabled(tester), isTrue);

      fixture
        ..width = 300
        ..rebuild();
      await tester.pump();
      expect(fixture.controlsEnabled(tester), isFalse);
      await tester.pumpAndSettle();
      final reads = manager.requests.length;

      fixture
        ..width = 600
        ..rebuild();
      await tester.pump();
      await tester.pump();
      expect(manager.requests, hasLength(reads));
      expect(fixture.controlsEnabled(tester), isTrue);
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        fixture.rebuild();
        await tester.pump();
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(fixture.controlsEnabled(tester), isTrue);
      }
      expect(manager.requests, hasLength(reads));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('swapping to an already visible notifier resumes autoplay '
      'for a settled active page', (tester) async {
    final files = TestImageFiles.create();
    addTearDown(files.dispose);
    final manager = ControlledImageCacheManager();
    final fixture = PostMediaSlideshowHarness(
      media: [slideshowMedia(1), slideshowMedia(2)],
      cacheManager: manager,
    );
    addTearDown(fixture.dispose);
    fixture.visibility.value = false;
    await fixture.pump(tester);
    await completeSlideshowImage(
      tester,
      manager,
      0,
      files.createSizedPng(64, 64).readAsBytesSync(),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(fixture.controller(tester).page, 0);
    final hidden = fixture.visibility;
    addTearDown(hidden.dispose);
    fixture
      ..visibility = ValueNotifier(true)
      ..rebuild();
    await tester.pump();
    await tester.pump();
    expect(fixture.controlsEnabled(tester), isTrue);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 2));
    expect(fixture.controller(tester).page, closeTo(1, 0.01));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual image completion cannot restart autoplay during Gallery, '
      'return resumes', (tester) async {
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
    expect(find.byType(GalleryPreviewScreen), findsOneWidget);
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
    expect(find.byType(GalleryPreviewScreen), findsNothing);
    await tester.pump(); // First tick after the outgoing Route is disposed.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 2));
    expect(controller.page, closeTo(1, 0.01));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

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
    expect(find.byType(GalleryPreviewScreen), findsOneWidget);
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

  testWidgets('an actual Block leaves its result pending and frees admission', (
    tester,
  ) async {
    var blockGallery = true;
    final fixture = PostMediaSlideshowHarness(
      media: [slideshowMedia(1), slideshowMedia(2)],
      onEnter: (_, _, next, _) {
        if (blockGallery && next.matchedLocation == '/gallery') {
          GalleryPreviewScreen.refuseOpening(next.extra);
          return const Block.stop();
        }
        return const Allow();
      },
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    await tester.pump();
    var returned = false;
    unawaited(openSlideshowGallery(tester).then((_) => returned = true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GalleryPreviewScreen), findsNothing);
    expect(returned, isFalse);

    blockGallery = false;
    await tester.tap(find.byType(PageView).hitTestable());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(GalleryPreviewScreen), findsOneWidget);
    expect(returned, isFalse);
  });

  testWidgets('old Gallery removal cannot release a new slideshow owner', (
    tester,
  ) async {
    final fixture = PostMediaSlideshowHarness(
      media: [slideshowMedia(1), slideshowMedia(2)],
    );
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    final slideshow = find.byType(PostMediaSlideshow, skipOffstage: false);
    final formerOwner = tester.state(slideshow);
    await tester.tap(find.byType(PageView).hitTestable());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final gallery = find.byType(GalleryPreviewScreen);
    final formerGallery = tester.state(gallery);
    final route = ModalRoute.of(tester.element(gallery))!;

    fixture
      ..ownerKey = const ValueKey('replacement slideshow')
      ..rebuild();
    await tester.pump();
    final currentOwner = tester.state(slideshow);
    expect(formerOwner.mounted, isFalse);
    expect(currentOwner, isNot(same(formerOwner)));

    // Synthetic opening and out-of-order physical removal: both slideshows
    // sit beneath Gallery, where a user cannot invoke these operations.
    unawaited(openSlideshowGallery(tester, skipOffstage: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final currentGallery = tester.state(gallery);
    expect(currentGallery, isNot(same(formerGallery)));
    route.navigator!.removeRoute(route);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(formerGallery.mounted, isFalse);
    expect(tester.state(gallery), same(currentGallery));

    var duplicateReturned = false;
    unawaited(
      openSlideshowGallery(tester, skipOffstage: false).then((_) {
        duplicateReturned = true;
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(duplicateReturned, isTrue);
    expect(tester.state(gallery), same(currentGallery));
    expect(fixture.controller(tester).page, 0);
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
