import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';

import '../support/route_ownership_fixture.dart';

void main() {
  group('category route parameters', () {
    const legacyIndexes = <(int, String)>[
      (0, 'nature'),
      (1, 'history'),
      (2, 'folklore'),
      (3, 'food'),
      (4, 'allure'),
      (5, 'experience'),
    ];

    for (final (index, slug) in legacyIndexes) {
      testWidgets('legacy index $index redirects to the $slug slug', (
        tester,
      ) async {
        final fixture = RouteOwnershipFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        fixture.router.go('/home/category/$index');
        await tester.pumpAndSettle();

        expect(fixture.uri.path, '/home/category/$slug');
        expect(find.text('Categorie'), findsOneWidget);
      });
    }

    testWidgets('legacy all-categories index -1 redirects to the all slug', (
      tester,
    ) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/home/category/-1');
      await tester.pumpAndSettle();

      expect(fixture.uri.path, '/home/category/all');
      expect(find.text('Categorie'), findsOneWidget);
    });

    testWidgets('legacy index redirect preserves child suffixes and isEvent', (
      tester,
    ) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/home/category/0/posts/1?isEvent=true');
      await tester.pumpAndSettle();

      expect(fixture.uri.path, '/home/category/nature/posts/1');
      expect(fixture.uri.queryParameters['type'], 'event');
      expect(find.byType(PostScreen), findsOneWidget);
    });

    testWidgets('canonical category slugs stay unchanged', (tester) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/home/category/nature');
      await tester.pumpAndSettle();

      expect(fixture.uri.path, '/home/category/nature');
      expect(find.text('Categorie'), findsOneWidget);
    });

    for (final slug in <String>['bogus', 'unknown', '6', '-2']) {
      testWidgets('invalid category value "$slug" renders the error screen', (
        tester,
      ) async {
        final fixture = RouteOwnershipFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        fixture.router.go('/home/category/$slug');
        await tester.pumpAndSettle();

        expect(find.byType(RouteErrorScreen), findsOneWidget);
      });
    }
  });

  group('post route parameters', () {
    testWidgets('legacy isEvent=true redirects to type=event', (tester) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/home/posts/1?isEvent=true');
      await tester.pumpAndSettle();

      expect(fixture.uri.queryParameters['type'], 'event');
      expect(fixture.uri.queryParameters.containsKey('isEvent'), isFalse);
      expect(find.byType(PostScreen), findsOneWidget);
    });

    testWidgets('legacy isEvent=false redirects to type=place', (tester) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/home/posts/2?isEvent=false');
      await tester.pumpAndSettle();

      expect(fixture.uri.queryParameters['type'], 'place');
      expect(fixture.uri.queryParameters.containsKey('isEvent'), isFalse);
    });

    testWidgets('missing type defaults to type=place', (tester) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/home/posts/2');
      await tester.pumpAndSettle();

      expect(fixture.uri.queryParameters['type'], 'place');
    });

    testWidgets('canonical type values stay unchanged', (tester) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/home/posts/1?type=event');
      await tester.pumpAndSettle();
      expect(fixture.uri.queryParameters['type'], 'event');

      fixture.router.go('/home/posts/2?type=place');
      await tester.pumpAndSettle();
      expect(fixture.uri.queryParameters['type'], 'place');
    });

    testWidgets('canonical type removes a simultaneous legacy isEvent', (
      tester,
    ) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go(
        '/home/posts/1?type=event&isEvent=false&source=restored',
      );
      await tester.pumpAndSettle();

      expect(fixture.uri.queryParameters['type'], 'event');
      expect(fixture.uri.queryParameters.containsKey('isEvent'), isFalse);
      expect(fixture.uri.queryParameters['source'], 'restored');
    });

    for (final type in <String>['bogus', 'Event', '']) {
      testWidgets('invalid type "$type" renders the error screen', (
        tester,
      ) async {
        final fixture = RouteOwnershipFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        fixture.router.go('/home/posts/1?type=$type');
        await tester.pumpAndSettle();

        expect(find.byType(RouteErrorScreen), findsOneWidget);
      });
    }

    for (final id in <String>['abc', '0', '-1', '9223372036854775808']) {
      testWidgets('invalid content id "$id" renders the error screen', (
        tester,
      ) async {
        final fixture = RouteOwnershipFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        fixture.router.go('/home/posts/$id?type=event');
        await tester.pumpAndSettle();

        expect(find.byType(RouteErrorScreen), findsOneWidget);
      });
    }
  });

  group('search route parameters', () {
    testWidgets('legacy search path redirects to the q query parameter', (
      tester,
    ) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/home/search_results/molise');
      await tester.pumpAndSettle();

      expect(fixture.uri.path, '/home/search_results');
      expect(fixture.uri.queryParameters['q'], 'molise');
      expect(find.text('Search molise root'), findsOneWidget);
    });

    testWidgets('legacy search post redirects to the canonical q and type', (
      tester,
    ) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/home/search_results/molise/posts/1?isEvent=true');
      await tester.pumpAndSettle();

      expect(fixture.uri.path, '/home/search_results/posts/1');
      expect(fixture.uri.queryParameters['q'], 'molise');
      expect(fixture.uri.queryParameters['type'], 'event');
      expect(find.byType(PostScreen), findsOneWidget);
    });

    testWidgets(
      'legacy search path value is authoritative over an existing q',
      (
        tester,
      ) async {
        final fixture = RouteOwnershipFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        fixture.router.go('/home/search_results/molise?q=other');
        await tester.pumpAndSettle();

        expect(fixture.uri.path, '/home/search_results');
        expect(fixture.uri.queryParameters['q'], 'molise');
      },
    );

    for (final text in <String>[
      'molise interno',
      'città di S. Elia',
      'castello/rocca',
      '60% autentico',
      'a+b?c=1',
      'emoji 😀',
    ]) {
      testWidgets('search text "$text" round-trips through q', (tester) async {
        final fixture = RouteOwnershipFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        fixture.router.goNamed(
          RouteNames.homeSearchResult,
          queryParameters: <String, String>{'q': text},
        );
        await tester.pumpAndSettle();

        expect(fixture.uri.path, '/home/search_results');
        expect(fixture.uri.queryParameters['q'], text);
        expect(find.text('Search $text root'), findsOneWidget);
      });

      testWidgets('legacy search path "$text" redirects with the same query', (
        tester,
      ) async {
        final fixture = RouteOwnershipFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        fixture.router.go(
          '/home/search_results/${Uri.encodeComponent(text)}',
        );
        await tester.pumpAndSettle();

        expect(fixture.uri.path, '/home/search_results');
        expect(fixture.uri.queryParameters['q'], text);
        expect(find.text('Search $text root'), findsOneWidget);
      });
    }
  });

  group('unknown routes', () {
    for (final path in <String>['/bogus', '/home/does-not-exist']) {
      testWidgets('unmatched path "$path" renders the route error screen', (
        tester,
      ) async {
        final fixture = RouteOwnershipFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        fixture.router.go(path);
        await tester.pumpAndSettle();

        expect(find.byType(RouteErrorScreen), findsOneWidget);
      });
    }

    testWidgets('direct error-page app-bar back falls home safely', (
      tester,
    ) async {
      final fixture = RouteOwnershipFixture();
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      fixture.router.go('/bogus');
      await tester.pumpAndSettle();
      expect(find.byType(RouteErrorScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(fixture.uri.path, '/home');
      expect(find.byType(RouteErrorScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
