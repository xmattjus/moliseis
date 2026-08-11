import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';

import '../support/fake_cache_manager.dart';
import '../support/predictive_back.dart';
import '../support/target_topology_fixture.dart';

void main() {
  testWidgets('back closes the gallery and cannot pop the map tab root', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final cacheManager = FakeCacheManager();
      addTearDown(() => unawaited(cacheManager.dispose()));
      final fixture = TargetTopologyFixture(
        initialLocation: '/map',
        cacheManager: cacheManager,
      );
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      expect(find.text('Map root'), findsOneWidget);
      await tester.tap(find.text('Open map gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPreviewScreen), findsOneWidget);

      await startPredictiveBack(tester);
      await commitPredictiveBack(tester);
      expect(find.byType(GalleryPreviewScreen), findsNothing);
      expect(find.text('Map root'), findsOneWidget);
      expect(fixture.uri.path, '/map');

      // The map is a tab root owned by its branch Navigator: system back
      // cannot pop it, and the sheet-like selection state stays on the map
      // page.
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Map root'), findsOneWidget);
      expect(fixture.uri.path, '/map');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('GoRouter replacement cannot orphan the gallery', (tester) async {
    final cacheManager = FakeCacheManager();
    addTearDown(() => unawaited(cacheManager.dispose()));
    final fixture = TargetTopologyFixture(cacheManager: cacheManager);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    fixture.router.go('/home/detail');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open gallery'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryPreviewScreen), findsOneWidget);

    fixture.router.go('/destination');
    await tester.pumpAndSettle();

    expect(find.byType(GalleryPreviewScreen), findsNothing);
    expect(find.text('Destination'), findsOneWidget);
    expect(fixture.uri.path, '/destination');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'visiting every branch leaves hidden branches unchanged after predictive '
    'back',
    (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final cacheManager = FakeCacheManager();
        addTearDown(() => unawaited(cacheManager.dispose()));
        final fixture = TargetTopologyFixture(cacheManager: cacheManager);
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        const branches = <String, String>{
          '/favourites': 'Favourites',
          '/events': 'Events',
          '/map': 'Map',
          '/home': 'Explore',
        };
        for (final entry in branches.entries) {
          fixture.router.go(entry.key);
          await tester.pumpAndSettle();
          expect(find.text('${entry.value} root'), findsOneWidget);
          await tester.tap(find.text('Increment ${entry.value}'));
          await tester.pump();
        }

        fixture.router.go('/home/detail');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open gallery'));
        await tester.pumpAndSettle();
        expect(find.byType(GalleryPreviewScreen), findsOneWidget);
        expect(fixture.matchedLocation, '/gallery');

        await startPredictiveBack(tester);
        await updatePredictiveBack(tester, 0.5);
        for (final key in fixture.branchNavigatorKeys) {
          expect(key.currentState!.canPop(), isFalse);
          expect(key.currentState!.widget.pages.length, 1);
        }

        await commitPredictiveBack(tester);

        expect(find.byType(GalleryPreviewScreen), findsNothing);
        expect(find.text('Detail page'), findsOneWidget);
        expect(fixture.matchedLocation, '/home/detail');
        expect(fixture.uri.path, '/home/detail');

        fixture.router.go('/home');
        await tester.pumpAndSettle();
        expect(
          find.text('Count: 1', skipOffstage: false),
          findsNWidgets(4),
        );
        for (final label in branches.values) {
          expect(find.text('$label root', skipOffstage: false), findsOneWidget);
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('rapid repeated back pops one visible root page per gesture', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final cacheManager = FakeCacheManager();
      addTearDown(() => unawaited(cacheManager.dispose()));
      final fixture = TargetTopologyFixture(cacheManager: cacheManager);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/home/detail');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPreviewScreen), findsOneWidget);

      // First gesture: predictive commit pops exactly the gallery.
      await startPredictiveBack(tester);
      await commitPredictiveBack(tester);
      expect(find.byType(GalleryPreviewScreen), findsNothing);
      expect(find.text('Detail page'), findsOneWidget);
      expect(fixture.uri.path, '/home/detail');

      // Second gesture, immediately repeated: pops exactly the detail page.
      await startPredictiveBack(tester);
      await commitPredictiveBack(tester);
      expect(find.text('Detail page'), findsNothing);
      expect(find.text('Explore root'), findsOneWidget);
      expect(fixture.uri.path, '/home');

      // The branch root cannot be popped by a third gesture.
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Explore root'), findsOneWidget);
      expect(fixture.uri.path, '/home');
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tab switches preserve branch root state', (tester) async {
    final fixture = TargetTopologyFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Increment Explore'));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);

    await tester.tap(find.text('Preferiti'));
    await tester.pumpAndSettle();
    expect(find.text('Favourites root'), findsOneWidget);
    expect(fixture.uri.path, '/favourites');

    await tester.tap(find.text('Esplora'));
    await tester.pumpAndSettle();
    expect(find.text('Explore root'), findsOneWidget);
    expect(find.text('Count: 1'), findsOneWidget);
    expect(fixture.uri.path, '/home');
  });

  testWidgets('active-tab reselect resets the branch to its initial location', (
    tester,
  ) async {
    final fixture = TargetTopologyFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    // The map branch keeps its non-initial location (a deep-linked selection).
    fixture.router.go('/map?contentId=5&type=event');
    await tester.pumpAndSettle();
    expect(fixture.uri.path, '/map');
    expect(fixture.uri.queryParameters['contentId'], '5');

    // Reselecting the active tab resets the branch to its initial location.
    await tester.tap(find.text('Mappa'));
    await tester.pumpAndSettle();
    expect(fixture.uri.path, '/map');
    expect(fixture.uri.queryParameters, isEmpty);

    // Reselecting the active Explore tab at its root location is a no-op.
    await tester.tap(find.text('Esplora'));
    await tester.pumpAndSettle();
    expect(fixture.uri.path, '/home');
    expect(fixture.uri.queryParameters, isEmpty);
  });
}
