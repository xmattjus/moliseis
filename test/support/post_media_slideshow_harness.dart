import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:moliseis/ui/post/widgets/components/post_media_slideshow.dart';
import 'package:provider/provider.dart';

import 'fake_cache_manager.dart';
import 'image_decode_support.dart';
import 'network_image_harness.dart';

/// Creates media whose URL identifies its controlled image request.
Media slideshowMedia(int id) => Media(
  remoteId: id,
  url: 'https://example.com/slideshow-$id.png',
  width: 800,
  height: 600,
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  areaName: 'Event',
  cityName: 'Molise',
);

/// Runs the real slideshow and gallery push Future on an isolated test router.
final class PostMediaSlideshowHarness {
  PostMediaSlideshowHarness({
    required this.media,
    CacheManager? cacheManager,
    OnEnter? onEnter,
  }) : cacheManager = cacheManager ?? FakeCacheManager() {
    router = GoRouter(
      onEnter: onEnter,
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ValueListenableBuilder(
            valueListenable: revision,
            builder: (_, _, _) => Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: PostMediaSlideshow(
                    key: ownerKey,
                    height: height,
                    media: media,
                    visibilityNotifier: visibility,
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/gallery',
          name: RouteNames.gallery,
          pageBuilder: GalleryPreviewScreen.buildPage,
        ),
      ],
    );
  }

  /// Replace, then [pump] and [rebuild], to change the effective manager.
  CacheManager cacheManager;
  final ValueNotifier<int> revision = ValueNotifier(0);
  ValueNotifier<bool> visibility = ValueNotifier(true);
  List<Media> media;
  Key? ownerKey;
  double width = 600;
  double height = 400;
  late final GoRouter router;

  void rebuild() => revision.value++;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    Provider<CacheManager>.value(
      value: cacheManager,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  PageController controller(WidgetTester tester) => tester
      .widget<PageView>(
        find.descendant(
          of: find.byType(PostMediaSlideshow, skipOffstage: false),
          matching: find.byType(PageView, skipOffstage: false),
        ),
      )
      .controller!;

  AppNetworkImage image(WidgetTester tester, int id) => tester
      .widgetList<AppNetworkImage>(
        find.byType(AppNetworkImage, skipOffstage: false),
      )
      .singleWhere((image) => image.url == slideshowMedia(id).url);

  bool controlsEnabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.byType(FilledButton, skipOffstage: false))
          .onPressed !=
      null;

  Future<void> dispose() async {
    router.dispose();
    revision.dispose();
    visibility.dispose();
    await cacheManager.dispose();
  }
}

/// Captures the mounted image's request before its cache key can be reused.
ImageStream slideshowImageStream(WidgetTester tester, String url) {
  final image = find.descendant(
    of: find.descendant(
      of: find.byType(PostMediaSlideshow, skipOffstage: false),
      matching: find.byWidgetPredicate(
        (widget) => widget is AppNetworkImage && widget.url == url,
        skipOffstage: false,
      ),
      skipOffstage: false,
    ),
    matching: find.byType(Image, skipOffstage: false),
  );
  final widget = tester.widget<Image>(image);
  return widget.image.resolve(
    createLocalImageConfiguration(
      tester.element(image),
      size: Size(widget.width!, widget.height!),
    ),
  );
}

/// Completes the provider and waits for its real first decoded frame.
/// Pass [stream] to observe a request captured before replacement or unmount.
Future<void> completeSlideshowImage(
  WidgetTester tester,
  ControlledImageCacheManager manager,
  int requestIndex,
  List<int> bytes, {
  ImageStream? stream,
}) async {
  final request =
      stream ??
      slideshowImageStream(tester, manager.requests[requestIndex].url);
  manager.complete(requestIndex, bytes);
  await tester.pump(); // Deliver the controlled response in the widget zone.
  final frame = await tester.runAsync(() => firstImageFrame(request));
  expect(frame, isNotNull);
  frame!.dispose();
  await tester.pump(); // Flush any loading notification.
  await tester.pump(); // Render controls after deferred publication.
}

/// Observes the real async gallery callback despite CardBase's void API.
Future<void> openSlideshowGallery(
  WidgetTester tester, {
  bool skipOffstage = true,
}) {
  final card = tester.widget<CardBase>(
    find
        .descendant(
          of: find.byType(PostMediaSlideshow, skipOffstage: skipOffstage),
          matching: find.byType(CardBase, skipOffstage: skipOffstage),
          skipOffstage: skipOffstage,
        )
        .first,
  );
  return Function.apply(card.onPressed!, const []) as Future<void>;
}
