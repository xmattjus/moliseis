import 'dart:async';
import 'dart:io';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/core/ui/media/bounded_cover_image.dart';
import 'package:moliseis/ui/core/ui/media/image_error_placeholder.dart';
import 'package:moliseis/ui/gallery/models/gallery_preview_route_data.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:provider/provider.dart';

import '../../../support/network_image_harness.dart';
import '../../../support/typography_harness.dart';

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'real gallery failure is legible against black under light app theme',
    (tester) async {
      final manager = ControlledImageCacheManager();
      addTearDown(manager.dispose);
      final media = Media(
        remoteId: 1,
        url: 'https://example.test/private-image.jpg',
        width: 800,
        height: 600,
        createdAt: DateTime.utc(2026),
        modifiedAt: DateTime.utc(2026),
        areaName: 'Area',
        cityName: 'Molise',
      );
      await tester.pumpWidget(
        Provider<CacheManager>.value(
          value: manager,
          child: typographyHarness(
            child: GalleryPreviewScreen(
              data: GalleryPreviewRouteData(media: [media], initialIndex: 0),
            ),
          ),
        ),
      );
      expect(
        Theme.of(tester.element(find.byType(GalleryPreviewScreen))).brightness,
        Brightness.light,
      );
      expect(manager.requests, hasLength(1));
      manager.fail(0, TimeoutException('PRIVATE_URL_CANARY'));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await tester.pump();
      final placeholder = find.byType(ImageErrorPlaceholder);
      expect(placeholder, findsOneWidget);
      expect(find.bySemanticsLabel('Immagine non disponibile'), findsOneWidget);
      final node = tester.getSemantics(placeholder);
      expect(node.getSemanticsData().label, 'Immagine non disponibile');
      expect(node.childrenCount, 0);
      final icon = tester.widget<Icon>(find.byIcon(Symbols.broken_image));
      final label = find.text('Immagine non disponibile');
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      expect((icon.color!.computeLuminance() + 0.05) / 0.05, greaterThan(3));
      expect(
        (paragraph.text.style!.color!.computeLuminance() + 0.05) / 0.05,
        greaterThan(4.5),
      );
      final bounds = tester.getRect(placeholder);
      for (final content in [label, find.byIcon(Symbols.broken_image)]) {
        final rect = tester.getRect(content);
        expect(bounds.intersect(rect), rect);
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThan(0));
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final fullResolution in [false, true]) {
    testWidgets('network GIF ${fullResolution ? 'full' : 'bounded'} '
        'keeps playback and deduped loading', (tester) async {
      final manager = ControlledImageCacheManager();
      addTearDown(manager.dispose);
      final states = <bool>[];
      final image = fullResolution
          ? AppNetworkImage.fullResolution(
              url: 'https://example.test/animated.gif',
              onImageLoading: states.add,
            )
          : AppNetworkImage(
              url: 'https://example.test/animated.gif',
              width: 86,
              height: 86,
              onImageLoading: states.add,
            );
      await tester.pumpWidget(
        networkImageHarness(manager: manager, child: image),
      );
      expect(states, [true]);
      final source = tester.widget<Image>(find.byType(Image)).image;
      if (fullResolution) {
        expect(source, isA<CachedNetworkImageProvider>());
      } else {
        expect(source, isA<BoundedCoverImage>());
      }
      manager.complete(
        0,
        File('test/fixtures/images/animated_1800x2.gif').readAsBytesSync(),
      );
      await tester.pump();
      final pixels = <int>{};
      for (var tick = 0; tick < 20 && pixels.length < 2; tick++) {
        await tester.runAsync(() => Future<void>(() {}));
        await tester.pump(const Duration(milliseconds: 100));
        final raw = tester.widget<RawImage>(find.byType(RawImage));
        if (raw.image == null) continue;
        // This engine's multiframe codec ignores the bounded resize request.
        expect((raw.image!.width, raw.image!.height), (1800, 2));
        await tester.runAsync(() async {
          pixels.add((await raw.image!.toByteData())!.getUint32(0));
        });
      }
      expect(pixels, hasLength(2));
      expect(states, [true, false]);
      expect(manager.requests, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
