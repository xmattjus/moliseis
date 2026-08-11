import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/ui/gallery/models/gallery_preview_route_data.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal_overlay.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:provider/provider.dart';
import 'package:swipe_image_gallery/widget/gallery.dart';

import '../../../support/fake_cache_manager.dart';

void main() {
  testWidgets('shows the requested page and updates metadata on swipe', (
    tester,
  ) async {
    final cacheManager = FakeCacheManager();
    addTearDown(cacheManager.dispose);
    final media = <Media>[
      _buildMedia(id: 1, title: 'First'),
      _buildMedia(id: 2, title: 'Second'),
    ];

    await tester.pumpWidget(
      Provider<CacheManager>.value(
        value: cacheManager,
        child: MaterialApp(
          home: GalleryPreviewScreen(
            data: GalleryPreviewRouteData(media: media, initialIndex: 1),
          ),
        ),
      ),
    );
    await tester.pump();

    var overlay = tester.widget<GalleryPreviewModalOverlay>(
      find.byType(GalleryPreviewModalOverlay),
    );
    expect(overlay.media, media[1]);
    expect(overlay.index, 1);

    final gallery = tester.widget<Gallery>(find.byType(Gallery));
    gallery.controller!.jumpToPage(0);
    await tester.pump();

    overlay = tester.widget<GalleryPreviewModalOverlay>(
      find.byType(GalleryPreviewModalOverlay),
    );
    expect(overlay.media, media[0]);
    expect(overlay.index, 0);
  });

  testWidgets('tapping the image toggles gallery chrome', (tester) async {
    final cacheManager = FakeCacheManager();
    addTearDown(cacheManager.dispose);

    await tester.pumpWidget(
      Provider<CacheManager>.value(
        value: cacheManager,
        child: MaterialApp(
          home: GalleryPreviewScreen(
            data: GalleryPreviewRouteData(
              media: [_buildMedia(id: 1, title: 'Image')],
              initialIndex: 0,
            ),
          ),
        ),
      ),
    );

    IgnorePointer overlayPointer() => tester.widget<IgnorePointer>(
      find.byKey(const ValueKey('galleryPreviewOverlay')),
    );

    expect(overlayPointer().ignoring, isFalse);
    await tester.tapAt(tester.getCenter(find.byType(Gallery)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(overlayPointer().ignoring, isTrue);

    await tester.tapAt(tester.getCenter(find.byType(Gallery)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(overlayPointer().ignoring, isFalse);
  });
}

Media _buildMedia({required int id, required String title}) => Media(
  remoteId: id,
  title: title,
  url: 'https://example.com/$id.jpg',
  width: 800,
  height: 600,
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  areaName: 'Event',
  cityName: 'Molise',
);
