import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';

import '../support/fake_cache_manager.dart';
import '../support/predictive_back.dart';
import '../support/target_topology_fixture.dart';

void main() {
  testWidgets('predictive back closes gallery without popping branch route', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final fixture = _buildFixture();
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPreviewScreen), findsOneWidget);
      expect(fixture.matchedLocation, '/gallery');

      await startPredictiveBack(tester);
      await commitPredictiveBack(tester);

      expect(fixture.uri.path, '/home/detail');
      expect(find.byType(GalleryPreviewScreen), findsNothing);
      expect(find.text('Detail page'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('GoRouter and root navigator pop the same managed route', (
    tester,
  ) async {
    final fixture = _buildFixture();
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open gallery'));
    await tester.pumpAndSettle();
    fixture.router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);

    await tester.tap(find.text('Open gallery'));
    await tester.pumpAndSettle();
    expect(await fixture.rootNavigatorKey.currentState!.maybePop(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);
  });

  testWidgets('direct navigation with invalid extra is safe', (tester) async {
    final fixture = _buildFixture(initialLocation: '/gallery');
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    expect(find.byType(GalleryUnavailableScreen), findsOneWidget);
    expect(find.text('Anteprima non disponibile.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical drag dismisses only the gallery route', (tester) async {
    final fixture = _buildFixture();
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open gallery'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(GalleryPreviewScreen), const Offset(0, 220));
    await tester.pumpAndSettle();

    expect(find.byType(GalleryPreviewScreen), findsNothing);
    expect(find.text('Detail page'), findsOneWidget);
  });

  testWidgets('context.pop closes the gallery route exactly once', (
    tester,
  ) async {
    final fixture = _buildFixture();
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open gallery'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryPreviewScreen), findsOneWidget);

    tester.element(find.byType(GalleryPreviewScreen)).pop();
    await tester.pumpAndSettle();

    expect(find.byType(GalleryPreviewScreen), findsNothing);
    expect(find.text('Detail page'), findsOneWidget);
    expect(fixture.uri.path, '/home/detail');
  });

  testWidgets('app-bar back pops the gallery route exactly once', (
    tester,
  ) async {
    final fixture = _buildFixture();
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open gallery'));
    await tester.pumpAndSettle();
    expect(find.byType(GalleryPreviewScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Indietro'));
    await tester.pumpAndSettle();

    expect(find.byType(GalleryPreviewScreen), findsNothing);
    expect(find.text('Detail page'), findsOneWidget);
    expect(fixture.uri.path, '/home/detail');
  });

  testWidgets('repeated gallery open/close cycles are stable', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final fixture = _buildFixture();
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      // Cycle 1: programmatic close.
      await tester.tap(find.text('Open gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPreviewScreen), findsOneWidget);
      fixture.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsOneWidget);

      // Cycle 2: app-bar back.
      await tester.tap(find.text('Open gallery'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Indietro'));
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsOneWidget);

      // Cycle 3: predictive commit.
      await tester.tap(find.text('Open gallery'));
      await tester.pumpAndSettle();
      await startPredictiveBack(tester);
      await commitPredictiveBack(tester);
      expect(find.byType(GalleryPreviewScreen), findsNothing);
      expect(find.text('Detail page'), findsOneWidget);

      expect(fixture.uri.path, '/home/detail');
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  group('target topology', () {
    testWidgets('predictive commit pops only the gallery', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final fixture = _buildFixture();
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        expect(find.text('Detail page'), findsOneWidget);
        expect(fixture.matchedLocation, '/home/detail');

        await tester.tap(find.text('Open gallery'));
        await tester.pumpAndSettle();
        expect(find.byType(GalleryPreviewScreen), findsOneWidget);
        expect(fixture.matchedLocation, '/gallery');

        await startPredictiveBack(tester);
        await updatePredictiveBack(tester, 0.5);
        await commitPredictiveBack(tester);

        expect(find.byType(GalleryPreviewScreen), findsNothing);
        expect(find.text('Detail page'), findsOneWidget);
        expect(fixture.matchedLocation, '/home/detail');
        expect(fixture.uri.path, '/home/detail');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('predictive cancel changes no route', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final fixture = _buildFixture();
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open gallery'));
        await tester.pumpAndSettle();
        expect(find.byType(GalleryPreviewScreen), findsOneWidget);
        expect(fixture.matchedLocation, '/gallery');

        final pagesBefore =
            fixture.rootNavigatorKey.currentState!.widget.pages.length;

        await startPredictiveBack(tester);
        await updatePredictiveBack(tester, 0.75);
        expect(find.byType(GalleryPreviewScreen), findsOneWidget);
        expect(fixture.matchedLocation, '/gallery');

        await cancelPredictiveBack(tester);

        expect(find.byType(GalleryPreviewScreen), findsOneWidget);
        expect(fixture.matchedLocation, '/gallery');
        expect(
          fixture.rootNavigatorKey.currentState!.widget.pages.length,
          pagesBefore,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets(
      'predictive update drives the transition without route mutation',
      (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final fixture = _buildFixture();
          await tester.pumpWidget(fixture.app);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Open gallery'));
          await tester.pumpAndSettle();
          expect(find.byType(GalleryPreviewScreen), findsOneWidget);

          final pagesBefore =
              fixture.rootNavigatorKey.currentState!.widget.pages.length;
          final galleryRoute = ModalRoute.of<void>(
            tester.element(find.byType(GalleryPreviewScreen)),
          )!;

          await startPredictiveBack(tester);
          expect(galleryRoute.animation!.value, closeTo(1.0, 0.05));

          await updatePredictiveBack(tester, 0.25);
          expect(galleryRoute.animation!.value, closeTo(0.75, 0.05));
          expect(fixture.matchedLocation, '/gallery');
          expect(
            fixture.rootNavigatorKey.currentState!.widget.pages.length,
            pagesBefore,
          );

          await updatePredictiveBack(tester, 0.5);
          expect(galleryRoute.animation!.value, closeTo(0.5, 0.05));
          expect(fixture.matchedLocation, '/gallery');
          expect(
            fixture.rootNavigatorKey.currentState!.widget.pages.length,
            pagesBefore,
          );

          await cancelPredictiveBack(tester);
          expect(find.byType(GalleryPreviewScreen), findsOneWidget);
          expect(fixture.matchedLocation, '/gallery');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets('fallback back pops only the gallery', (tester) async {
      final fixture = _buildFixture();
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open gallery'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryPreviewScreen), findsOneWidget);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(GalleryPreviewScreen), findsNothing);
      expect(find.text('Detail page'), findsOneWidget);
      expect(fixture.matchedLocation, '/home/detail');
      expect(fixture.uri.path, '/home/detail');
    });
  });
}

/// Builds the four-branch fixture on the detail page with a gallery-capable
/// cache manager.
TargetTopologyFixture _buildFixture({String initialLocation = '/home/detail'}) {
  final cacheManager = FakeCacheManager();
  addTearDown(() => unawaited(cacheManager.dispose()));
  final fixture = TargetTopologyFixture(
    initialLocation: initialLocation,
    cacheManager: cacheManager,
  );
  addTearDown(fixture.dispose);
  return fixture;
}
