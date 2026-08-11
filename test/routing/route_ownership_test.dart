import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/ui/gallery/models/gallery_preview_route_data.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:moliseis/ui/post/widgets/components/post_section_nearby_content.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';

import '../support/fixtures.dart';
import '../support/route_ownership_fixture.dart';

void main() {
  testWidgets('each tab root stays on its branch Navigator with one page', (
    tester,
  ) async {
    final fixture = RouteOwnershipFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    const destinations = <(String, String, String)>[
      ('explore', RoutePaths.home, 'Home'),
      ('favourites', RoutePaths.favourites, 'Favourites'),
      ('events', RoutePaths.events, 'Events'),
      ('map', RoutePaths.geoMap, 'Map'),
    ];
    final branchKeys = <String, GlobalKey<NavigatorState>>{
      'explore': fixture.exploreNavigatorKey,
      'favourites': fixture.favouritesNavigatorKey,
      'events': fixture.eventsNavigatorKey,
      'map': fixture.mapNavigatorKey,
    };

    for (final (label, path, rootLabel) in destinations) {
      fixture.router.go(path);
      await tester.pumpAndSettle();
      expect(
        find.text('$rootLabel root'),
        findsOneWidget,
        reason: '$label root must be visible after deep-linking to $path',
      );
      expect(
        branchKeys[label]!.currentState!.widget.pages.length,
        1,
        reason: '$label branch Navigator must own exactly its root page',
      );
      expect(
        fixture.rootNavigatorKey.currentState!.widget.pages.length,
        1,
        reason: 'root Navigator must own only the shell page on $path',
      );
    }
  });

  testWidgets('category page is root-owned while branch keeps its root', (
    tester,
  ) async {
    final fixture = RouteOwnershipFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    fixture.router.go('/home/category/nature');
    await tester.pumpAndSettle();

    expect(find.text('Categorie'), findsOneWidget);
    expect(fixture.uri.path, '/home/category/nature');
    expect(
      fixture.exploreNavigatorKey.currentState!.widget.pages.length,
      1,
    );
    expect(
      fixture.rootNavigatorKey.currentState!.widget.pages.length,
      2,
      reason: 'root Navigator must own the shell and the category page',
    );
  });

  testWidgets('post page is root-owned while branch keeps its root', (
    tester,
  ) async {
    final fixture = RouteOwnershipFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    fixture.router.go('/home/posts/1?type=event');
    await tester.pumpAndSettle();

    expect(find.byType(PostScreen), findsOneWidget);
    expect(fixture.uri.path, '/home/posts/1');
    expect(
      fixture.exploreNavigatorKey.currentState!.widget.pages.length,
      1,
    );
    expect(
      fixture.rootNavigatorKey.currentState!.widget.pages.length,
      2,
      reason: 'root Navigator must own the shell and the post page',
    );
  });

  testWidgets('search results page is root-owned while branch keeps its root', (
    tester,
  ) async {
    final fixture = RouteOwnershipFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    fixture.router.go('/home/search_results?q=molise');
    await tester.pumpAndSettle();

    expect(find.text('Search molise root'), findsOneWidget);
    expect(fixture.uri.path, '/home/search_results');
    expect(
      fixture.exploreNavigatorKey.currentState!.widget.pages.length,
      1,
    );
    expect(
      fixture.rootNavigatorKey.currentState!.widget.pages.length,
      2,
      reason: 'root Navigator must own the shell and the search-results page',
    );
  });

  testWidgets('back from a root-owned post returns to its declarative parent', (
    tester,
  ) async {
    final fixture = RouteOwnershipFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    fixture.router.go('/home/posts/1?type=event');
    await tester.pumpAndSettle();
    expect(find.byType(PostScreen), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Home root'), findsOneWidget);
    expect(fixture.uri.path, '/home');
    expect(
      fixture.exploreNavigatorKey.currentState!.widget.pages.length,
      1,
    );
    expect(
      fixture.rootNavigatorKey.currentState!.widget.pages.length,
      1,
      reason: 'root Navigator must return to owning only the shell page',
    );
  });

  testWidgets('back from a category post returns to its category parent', (
    tester,
  ) async {
    final fixture = RouteOwnershipFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    fixture.router.go('/home/category/nature/posts/1?type=event');
    await tester.pumpAndSettle();
    expect(find.byType(PostScreen), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.text('Categorie'), findsOneWidget);
    expect(fixture.uri.path, '/home/category/nature');
    expect(
      fixture.exploreNavigatorKey.currentState!.widget.pages.length,
      1,
    );
    expect(
      fixture.rootNavigatorKey.currentState!.widget.pages.length,
      2,
      reason: 'root Navigator must keep the shell and the category page',
    );
  });

  testWidgets('hidden branch Navigators hold no poppable detail route', (
    tester,
  ) async {
    final fixture = RouteOwnershipFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    for (final path in <String>[
      RoutePaths.favourites,
      RoutePaths.events,
      RoutePaths.geoMap,
    ]) {
      fixture.router.go(path);
      await tester.pumpAndSettle();
    }

    fixture.router.go('/home/posts/1?type=event');
    await tester.pumpAndSettle();
    expect(find.byType(PostScreen), findsOneWidget);

    for (final key in fixture.branchNavigatorKeys) {
      expect(key.currentState!.widget.pages.length, 1);
      expect(key.currentState!.canPop(), isFalse);
    }
    expect(fixture.rootNavigatorKey.currentState!.canPop(), isTrue);
  });

  testWidgets('gallery location is root-owned, replacing the shell', (
    tester,
  ) async {
    final fixture = RouteOwnershipFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    fixture.router.go(RoutePaths.gallery);
    await tester.pumpAndSettle();

    expect(find.byType(GalleryUnavailableScreen), findsOneWidget);
    expect(fixture.uri.path, RoutePaths.gallery);
    // A top-level gallery location has no branch match: the gallery page
    // replaces the shell on the root Navigator and no branch Navigator is
    // involved.
    expect(fixture.exploreNavigatorKey.currentState, isNull);
    expect(
      fixture.rootNavigatorKey.currentState!.widget.pages.length,
      1,
      reason: 'root Navigator must own only the gallery page',
    );
  });

  testWidgets('pushed gallery is root-owned while branch keeps its root', (
    tester,
  ) async {
    final fixture = RouteOwnershipFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    unawaited(
      fixture.router.pushNamed(
        RouteNames.gallery,
        extra: GalleryPreviewRouteData(
          media: [_buildMedia()],
          initialIndex: 0,
        ).toExtra(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GalleryPreviewScreen), findsOneWidget);
    expect(
      fixture.exploreNavigatorKey.currentState!.widget.pages.length,
      1,
    );
    expect(
      fixture.rootNavigatorKey.currentState!.widget.pages.length,
      2,
      reason: 'root Navigator must own the shell and the pushed gallery page',
    );
  });

  testWidgets('branch root state persists across tab switches', (tester) async {
    final fixture = RouteOwnershipFixture();
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Increment'));
    await tester.pump();

    fixture.router.go(RoutePaths.favourites);
    await tester.pumpAndSettle();
    expect(find.text('Favourites root'), findsOneWidget);

    fixture.router.go(RoutePaths.home);
    await tester.pumpAndSettle();
    expect(find.text('Count: 1'), findsOneWidget);
    expect(find.text('Home root'), findsOneWidget);
  });

  testWidgets(
    'nearby post navigation updates URL, identity, and search parent',
    (tester) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go(
        '/home/search_results/posts/1?q=molise&type=event',
      );
      await tester.pumpAndSettle();
      final firstKey = tester.widget<PostScreen>(find.byType(PostScreen)).key;

      await tester.scrollUntilVisible(
        find.byType(PostSectionNearbyContent),
        300,
        scrollable: find
            .descendant(
              of: find.byType(PostScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      tester
          .widget<PostSectionNearbyContent>(
            find.byType(PostSectionNearbyContent),
          )
          .onContentPressed(makeEvent(remoteId: 2));
      await tester.pumpAndSettle();

      final uri = fixture.uri;
      expect(uri.path, '/home/search_results/posts/2');
      expect(uri.queryParameters['q'], 'molise');
      expect(uri.queryParameters['type'], 'event');
      expect(
        tester.widget<PostScreen>(find.byType(PostScreen)).key,
        isNot(firstKey),
      );

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Search molise root'), findsOneWidget);
    },
  );
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
