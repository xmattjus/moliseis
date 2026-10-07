import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/post/widgets/post_screen.dart';

import '../support/route_ownership_fixture.dart';

void main() {
  group('category route parameters', () {
    for (final slug in <String>[
      'nature',
      'history',
      'folklore',
      'food',
      'allure',
      'experience',
      'all',
    ]) {
      testWidgets('canonical category $slug stays unchanged', (tester) async {
        final fixture = RouteOwnershipFixture(
          initialLocation: '/home/category/$slug',
        );
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        expect(fixture.uri.path, '/home/category/$slug');
        expect(find.text('Categorie'), findsOneWidget);
      });
    }

    for (final slug in <String>[
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
      '-1',
      'bogus',
      'unknown',
      '6',
      '-2',
    ]) {
      testWidgets('invalid category "$slug" errors without rewriting', (
        tester,
      ) async {
        final fixture = RouteOwnershipFixture(
          initialLocation: '/home/category/$slug',
        );
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        expect(fixture.uri.path, '/home/category/$slug');
        expect(find.byType(RouteErrorScreen), findsOneWidget);
        expect(
          fixture.exploreNavigatorKey.currentState!.widget.pages.length,
          2,
        );
        expect(fixture.rootNavigatorKey.currentState!.widget.pages.length, 1);
      });
    }
  });

  group('nested Category Post validation', () {
    for (final (branchIndex, branch) in <(int, String)>[
      (0, 'home'),
      (1, 'favourites'),
      (2, 'events'),
    ]) {
      for (final slug in <String>['0', 'bogus']) {
        testWidgets('$branch rejects $slug before building the child Post', (
          tester,
        ) async {
          final location = '/$branch/category/$slug/posts/1?type=event';
          final fixture = RouteOwnershipFixture(initialLocation: location);
          addTearDown(fixture.dispose);
          await tester.pumpWidget(fixture.app);
          await tester.pumpAndSettle();

          expect(fixture.uri.toString(), location);
          expect(find.byType(RouteErrorScreen), findsOneWidget);
          expect(find.byType(PostScreen, skipOffstage: false), findsNothing);
          expect(fixture.eventRepository.getByIdCallCount, 0);
          expect(fixture.placeRepository.getByIdCallCount, 0);
        });
      }

      testWidgets('$branch preserves canonical all and its child place Post', (
        tester,
      ) async {
        final location = '/$branch/category/all/posts/2?type=place';
        final fixture = RouteOwnershipFixture(initialLocation: location);
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        expect(fixture.uri.toString(), location);
        expect(
          find.byType(RouteErrorScreen, skipOffstage: false),
          findsNothing,
        );
        final post = tester.widget<PostScreen>(find.byType(PostScreen));
        expect(post.isEvent, isFalse);
        expect(post.viewModel.content.remoteId, 2);
        expect(fixture.rootNavigatorKey.currentState!.widget.pages.length, 1);
        final branchKey = fixture.branchNavigatorKeys[branchIndex];
        expect(branchKey.currentState!.widget.pages.length, 3);
      });
    }
  });

  group('post route parameters', () {
    for (final location in <String>[
      '/home/posts/2',
      '/home/posts/1?isEvent=true',
      '/home/posts/2?isEvent=false',
      '/home/posts/1?isEvent=unknown',
    ]) {
      testWidgets('$location errors without migrating to type', (tester) async {
        final fixture = RouteOwnershipFixture(initialLocation: location);
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        expect(fixture.uri.toString(), location);
        expect(fixture.uri.queryParameters.containsKey('type'), isFalse);
        expect(find.byType(RouteErrorScreen), findsOneWidget);
        expect(find.byType(PostScreen), findsNothing);
      });
    }

    for (final (id, type) in <(int, String)>[(1, 'event'), (2, 'place')]) {
      for (final stale in <String?>[null, 'true', 'false', 'unknown']) {
        testWidgets('canonical $type accepts stale isEvent=$stale unchanged', (
          tester,
        ) async {
          final location =
              '/home/posts/$id?type=$type${stale == null ? '' : '&isEvent=$stale'}';
          final fixture = RouteOwnershipFixture(initialLocation: location);
          addTearDown(fixture.dispose);
          await tester.pumpWidget(fixture.app);
          await tester.pumpAndSettle();

          expect(fixture.uri.toString(), location);
          final post = tester.widget<PostScreen>(find.byType(PostScreen));
          expect(post.isEvent, type == 'event');
          expect(post.viewModel.content.remoteId, id);
        });
      }
    }

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
    for (final location in <String>[
      '/home/search_results/molise',
      '/home/search_results/molise/posts/1?type=event',
      '/home/search_results/molise?q=other',
    ]) {
      testWidgets('legacy Search $location is unmatched without rewriting', (
        tester,
      ) async {
        final fixture = RouteOwnershipFixture(initialLocation: location);
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        expect(fixture.uri.toString(), location);
        expect(
          fixture.router.configuration.findMatch(fixture.uri).isError,
          isTrue,
        );
        expect(find.byType(RouteErrorScreen), findsOneWidget);
        expect(find.byType(PostScreen), findsNothing);
      });
    }

    testWidgets('cold Search Post reconstructs its Search parent', (
      tester,
    ) async {
      final fixture = RouteOwnershipFixture(
        initialLocation: '/home/search_results/posts/1?q=molise&type=event',
      );
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      expect(
        fixture.uri.toString(),
        '/home/search_results/posts/1?q=molise&type=event',
      );
      expect(find.byType(PostScreen), findsOneWidget);
      expect(fixture.exploreNavigatorKey.currentState!.widget.pages.length, 3);
      expect(fixture.rootNavigatorKey.currentState!.widget.pages.length, 1);
      fixture.router.pop();
      await tester.pumpAndSettle();
      expect(fixture.uri.path, '/home/search_results');
      expect(fixture.uri.queryParameters['q'], 'molise');
      expect(find.text('Search molise root'), findsOneWidget);
    });

    testWidgets('missing Search q remains an empty query', (tester) async {
      final fixture = RouteOwnershipFixture(
        initialLocation: '/home/search_results',
      );
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      expect(fixture.uri.toString(), '/home/search_results');
      expect(find.text('Search  root'), findsOneWidget);
    });

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

        fixture.router.goNamed(
          RouteNames.homeSearchResultPost,
          pathParameters: <String, String>{'id': '1'},
          queryParameters: <String, String>{'q': text, 'type': 'event'},
        );
        await tester.pumpAndSettle();
        expect(fixture.uri.path, '/home/search_results/posts/1');
        expect(fixture.uri.queryParameters, <String, String>{
          'q': text,
          'type': 'event',
        });
        expect(
          tester
              .widget<PostScreen>(find.byType(PostScreen))
              .viewModel
              .content
              .remoteId,
          1,
        );
        expect(
          fixture.exploreNavigatorKey.currentState!.widget.pages.length,
          3,
        );
        expect(fixture.rootNavigatorKey.currentState!.widget.pages.length, 1);

        fixture.router.pop();
        await tester.pumpAndSettle();
        expect(fixture.uri.path, '/home/search_results');
        expect(fixture.uri.queryParameters['q'], text);
        expect(find.text('Search $text root'), findsOneWidget);
      });

      testWidgets('legacy search path "$text" is unmatched', (tester) async {
        final fixture = RouteOwnershipFixture();
        addTearDown(fixture.dispose);
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        fixture.router.go('/home/search_results/${Uri.encodeComponent(text)}');
        await tester.pumpAndSettle();

        expect(
          fixture.uri.path,
          '/home/search_results/${Uri.encodeComponent(text)}',
        );
        expect(fixture.uri.queryParameters.containsKey('q'), isFalse);
        expect(
          fixture.router.configuration.findMatch(fixture.uri).isError,
          isTrue,
        );
        expect(find.byType(RouteErrorScreen), findsOneWidget);
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
