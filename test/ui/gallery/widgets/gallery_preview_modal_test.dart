import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal.dart';
import 'package:provider/provider.dart';
import 'package:swipe_image_gallery/widget/gallery_overlay.dart';

import '../../../support/fake_cache_manager.dart';

void main() {
  testWidgets('closes the overlay stream after the gallery is dismissed', (
    tester,
  ) async {
    final cacheManager = FakeCacheManager();
    addTearDown(cacheManager.dispose);
    late BuildContext context;

    await tester.pumpWidget(
      Provider<CacheManager>.value(
        value: cacheManager,
        child: MaterialApp(
          home: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final galleryFuture = GalleryPreviewModal.show(
      context: context,
      media: [_buildMedia()],
      initialIndex: 0,
    );
    await tester.pump();

    final overlay = tester.widget<GalleryOverlay>(find.byType(GalleryOverlay));
    final overlayController = overlay.overlayController;
    expect(overlayController.isClosed, isFalse);

    Navigator.of(context, rootNavigator: true).pop();
    await tester.pump(const Duration(milliseconds: 400));
    await galleryFuture;

    expect(overlayController.isClosed, isTrue);
  });
}

Media _buildMedia() => Media(
  remoteId: 1,
  url: 'https://example.com/image.jpg',
  width: 800,
  height: 600,
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  areaName: 'Event',
  cityName: 'Molise',
);
