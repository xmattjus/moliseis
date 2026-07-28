import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/ui/core/ui/media/app_network_image.dart';
import 'package:moliseis/ui/post/widgets/components/post_media_slideshow.dart';
import 'package:provider/provider.dart';

import '../../../../support/fake_cache_manager.dart';

void main() {
  testWidgets('queued image loading callback is safe after disposal', (
    tester,
  ) async {
    final cacheManager = FakeCacheManager();
    final visibilityNotifier = ValueNotifier(true);
    addTearDown(cacheManager.dispose);
    addTearDown(visibilityNotifier.dispose);

    await tester.pumpWidget(
      Provider<CacheManager>.value(
        value: cacheManager,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: PostMediaSlideshow(
                height: 400,
                media: [_buildMedia()],
                visibilityNotifier: visibilityNotifier,
              ),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<AppNetworkImage>(
      find.byType(AppNetworkImage),
    );
    image.onImageLoading!(false);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
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
