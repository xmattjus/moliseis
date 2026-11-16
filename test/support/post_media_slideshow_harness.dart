import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/cards/card_base.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
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
  PostMediaSlideshowHarness({required this.media, CacheManager? cacheManager})
    : cacheManager = cacheManager ?? FakeCacheManager() {
    router = GoRouter(
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
          builder: (_, _) => const Scaffold(body: Text('Open gallery')),
        ),
      ],
    );
  }

  /// Replace, then [pump] and [rebuild], to change the effective manager.
  CacheManager cacheManager;
  final ValueNotifier<int> revision = ValueNotifier(0);
  ValueNotifier<bool> visibility = ValueNotifier(true);
  List<Media> media;
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

/// Completes the provider and waits for its real first decoded frame.
Future<void> completeSlideshowImage(
  WidgetTester tester,
  ControlledImageCacheManager manager,
  int requestIndex,
  List<int> bytes,
) async {
  manager.complete(requestIndex, bytes);
  await tester.pump();
  final url = manager.requests[requestIndex].url;
  final image = tester.widget<Image>(
    find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is AppNetworkImage && widget.url == url,
        skipOffstage: false,
      ),
      matching: find.byType(Image, skipOffstage: false),
    ),
  );
  final frame = await tester.runAsync(() => decodeImage(image.image));
  frame?.dispose();
  await tester.pump();
  await tester.pump();
}

/// Observes the real async gallery callback despite CardBase's void API.
Future<void> openSlideshowGallery(WidgetTester tester) {
  final card = tester.widget<CardBase>(
    find
        .descendant(
          of: find.byType(PostMediaSlideshow),
          matching: find.byType(CardBase),
        )
        .first,
  );
  return Function.apply(card.onPressed!, const []) as Future<void>;
}
