import 'dart:async' show unawaited;

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_modal_overlay.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:swipe_image_gallery/widget/gallery.dart';

import '../support/fake_cache_manager.dart';
import '../support/target_topology_fixture.dart';

void main() {
  group('restoration behavior', () {
    group('single-page gallery', () {
      testWidgets(
        'restoration restores branch state and the serializable gallery payload',
        (
          tester,
        ) async {
          final cacheManager = FakeCacheManager();
          addTearDown(() => unawaited(cacheManager.dispose()));
          final holder = _FixtureHolder();

          await tester.pumpWidget(
            _RestorableHarness(cacheManager: cacheManager, holder: holder),
          );
          await tester.pumpAndSettle();
          final before = holder.fixture!;

          // Visit other branches so their navigator state is part of the shell.
          before.router.go('/favourites');
          await tester.pumpAndSettle();
          before.router.go('/map?contentId=5&type=event');
          await tester.pumpAndSettle();
          before.router.go('/home/detail');
          await tester.pumpAndSettle();

          // Push the gallery with its serializable in-memory payload.
          await tester.tap(find.text('Open gallery'));
          await tester.pumpAndSettle();
          expect(find.byType(GalleryPreviewScreen), findsOneWidget);

          await tester.restartAndRestore();
          await tester.pumpAndSettle();

          // The harness rebuilt a fresh router from the saved restoration bucket.
          // The declarative stack, the shell branch state, and the serializable
          // gallery extra all survive: the pushed gallery route is restored with
          // its media payload intact (go_router's route-match codec JSON-encodes
          // serializable extras), with no exceptions.
          final after = holder.fixture!;
          expect(after, isNot(same(before)));
          expect(after.uri.path, '/home/detail');
          expect(after.matchedLocation, '/gallery');
          final restoredGallery = tester.widget<GalleryPreviewScreen>(
            find.byType(GalleryPreviewScreen),
          );
          expect(restoredGallery.data.initialIndex, 0);
          expect(restoredGallery.data.media.single.remoteId, 1);
          expect(
            restoredGallery.data.media.single.url,
            'https://example.com/image.jpg',
          );
          expect(tester.takeException(), isNull);

          // The restored gallery pops like any managed route; returning to the
          // explore root reveals the restored shell and its tab bar.
          after.router.pop();
          await tester.pumpAndSettle();
          expect(find.byType(GalleryPreviewScreen), findsNothing);
          expect(find.text('Detail page'), findsOneWidget);
          expect(after.uri.path, '/home/detail');

          after.router.go('/home');
          await tester.pumpAndSettle();
          expect(find.text('Explore root'), findsOneWidget);

          // The restored shell keeps every visited branch reachable.
          await tester.tap(find.text('Preferiti'));
          await tester.pumpAndSettle();
          expect(find.text('Favourites root'), findsOneWidget);
          expect(after.uri.path, '/favourites');

          await tester.tap(find.text('Mappa'));
          await tester.pumpAndSettle();
          expect(find.text('Map root'), findsOneWidget);
          expect(after.uri.path, '/map');

          // The restored router stays fully functional: pop the restored gallery
          // and open it again from a fresh navigation.
          after.router.go('/home/detail');
          await tester.pumpAndSettle();
          expect(find.text('Detail page'), findsOneWidget);

          await tester.tap(find.text('Open gallery'));
          await tester.pumpAndSettle();
          expect(find.byType(GalleryPreviewScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    });

    group('multi-page gallery', () {
      testWidgets(
        'restorationBundle round-trips the gallery extra',
        (tester) async {
          final cacheManager = FakeCacheManager();
          addTearDown(() => unawaited(cacheManager.dispose()));
          final holder = _FixtureHolder();

          await tester.pumpWidget(
            _RestorableHarness(cacheManager: cacheManager, holder: holder),
          );
          await tester.pumpAndSettle();
          final before = holder.fixture!;

          before.router.go('/home/detail');
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open gallery on page 3'));
          await tester.pumpAndSettle();
          expect(find.byType(GalleryPreviewScreen), findsOneWidget);

          final preRestore = tester.widget<GalleryPreviewScreen>(
            find.byType(GalleryPreviewScreen),
          );
          expect(preRestore.data.initialIndex, 2);
          expect(preRestore.data.media.length, 4);
          expect(preRestore.data.media[2].remoteId, 3);

          await tester.restartAndRestore();
          await tester.pumpAndSettle();

          final after = holder.fixture!;
          expect(after, isNot(same(before)));
          expect(after.uri.path, '/home/detail');
          expect(after.matchedLocation, '/gallery');

          final restored = tester.widget<GalleryPreviewScreen>(
            find.byType(GalleryPreviewScreen),
          );
          // The immutable route payload retains its original initial index.
          // Restoring a page selected after swiping is covered below.
          expect(restored.data.initialIndex, 2);
          expect(restored.data.media.length, 4);
          expect(restored.data.media[2].remoteId, 3);
          expect(restored.data.media[2].url, 'https://example.com/3.jpg');
          expect(tester.takeException(), isNull);

          after.router.pop();
          await tester.pumpAndSettle();
          expect(find.byType(GalleryPreviewScreen), findsNothing);
          expect(find.text('Detail page'), findsOneWidget);
          expect(after.uri.path, '/home/detail');
        },
      );

      testWidgets(
        'restoration restores the selected page after a gallery page change',
        (tester) async {
          final cacheManager = FakeCacheManager();
          addTearDown(() => unawaited(cacheManager.dispose()));
          final holder = _FixtureHolder();

          await tester.pumpWidget(
            _RestorableHarness(cacheManager: cacheManager, holder: holder),
          );
          await tester.pumpAndSettle();
          final before = holder.fixture!;

          before.router.go('/home/detail');
          await tester.pumpAndSettle();

          // The gallery opens on page 3 (index 2), then the user selects page
          // 1 (index 0) before process death.
          await tester.tap(find.text('Open gallery on page 3'));
          await tester.pumpAndSettle();
          expect(find.byType(GalleryPreviewScreen), findsOneWidget);

          // Drive Gallery's PageView deterministically so its onSwipe callback
          // updates the live restorable index without drag hit-testing through
          // the modal overlay.
          final gallery = tester.widget<Gallery>(find.byType(Gallery));
          gallery.controller!.jumpToPage(0);
          await tester.pump();

          expect(gallery.controller!.page, closeTo(0, 0.001));
          final preRestoreOverlay = tester.widget<GalleryPreviewModalOverlay>(
            find.byType(GalleryPreviewModalOverlay),
          );
          expect(preRestoreOverlay.index, 0);
          expect(preRestoreOverlay.media.remoteId, 1);

          await tester.restartAndRestore();
          await tester.pumpAndSettle();

          final after = holder.fixture!;
          expect(after, isNot(same(before)));
          expect(after.uri.path, '/home/detail');
          expect(after.matchedLocation, '/gallery');

          // The route extra remains unchanged, while the Gallery itself opens
          // on the page selected after the route was first pushed.
          final restored = tester.widget<GalleryPreviewScreen>(
            find.byType(GalleryPreviewScreen),
          );
          expect(restored.data.initialIndex, 2);

          final restoredGallery = tester.widget<Gallery>(find.byType(Gallery));
          final restoredController = restoredGallery.controller!;
          expect(restoredController.initialPage, 0);
          expect(restoredController.page, closeTo(0, 0.001));

          final restoredOverlay = tester.widget<GalleryPreviewModalOverlay>(
            find.byType(GalleryPreviewModalOverlay),
          );
          expect(restoredOverlay.index, 0);
          expect(restoredOverlay.media.remoteId, 1);
          expect(restoredOverlay.media.url, 'https://example.com/1.jpg');
          expect(tester.takeException(), isNull);

          after.router.pop();
          await tester.pumpAndSettle();
          expect(find.byType(GalleryPreviewScreen), findsNothing);
          expect(find.text('Detail page'), findsOneWidget);
          expect(after.uri.path, '/home/detail');
        },
      );
    });
  });
}

/// Exposes the currently mounted fixture to the test body.
class _FixtureHolder {
  TargetTopologyFixture? fixture;
}

/// Stateful harness that builds a fresh [TargetTopologyFixture] on every
/// mount, so `tester.restartAndRestore` re-creates the router from the saved
/// restoration bucket instead of reusing the in-memory instance.
class _RestorableHarness extends StatefulWidget {
  const _RestorableHarness({
    required this.cacheManager,
    required this.holder,
  });

  final CacheManager cacheManager;
  final _FixtureHolder holder;

  @override
  State<_RestorableHarness> createState() => _RestorableHarnessState();
}

class _RestorableHarnessState extends State<_RestorableHarness> {
  late final TargetTopologyFixture fixture = TargetTopologyFixture(
    cacheManager: widget.cacheManager,
  );

  @override
  void initState() {
    super.initState();
    widget.holder.fixture = fixture;
  }

  @override
  void dispose() {
    fixture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => fixture.app;
}
