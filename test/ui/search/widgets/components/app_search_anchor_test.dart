import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/use-cases/explore_get_by_id_use_case.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/search/view_models/search_view_model.dart';
import 'package:moliseis/ui/search/widgets/components/app_search_anchor.dart';
import 'package:moliseis/ui/search/widgets/search_result_screen.dart';
import 'package:moliseis/utils/result.dart';

import '../../../../support/fake_repositories.dart';
import '../../../../support/fixtures.dart';
import '../../../../support/predictive_back.dart';

void main() {
  group('AppSearchAnchor', () {
    group('compact full-screen search', () {
      testWidgets('fallback back closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _compactFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        fixture.controller.text = 'molise';
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        _expectPopupClosed(fixture);
        expect(fixture.controller.text, 'molise');
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('predictive commit closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _compactFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        await startPredictiveBack(tester);
        await commitPredictiveBack(tester);

        _expectPopupClosed(fixture);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('leading button closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _compactFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
        await tester.pumpAndSettle();

        _expectPopupClosed(fixture);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets(
        'programmatic closeView closes the popup and keeps the route',
        (
          tester,
        ) async {
          final fixture = _compactFixture(cleanupOnClose: false);
          addTearDown(fixture.dispose);
          await fixture.pumpApp(tester);
          await _openSearch(tester, fixture);

          fixture.controller.closeView(null);
          await tester.pumpAndSettle();

          _expectPopupClosed(fixture);
          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    });

    group('expanded non-full-screen search', () {
      testWidgets('fallback back closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _expandedFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        _expectPopupClosed(fixture);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('barrier dismissal closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _expandedFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        await tester.tapAt(const Offset(640, 1500));
        await tester.pumpAndSettle();

        _expectPopupClosed(fixture);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('predictive commit closes the popup and keeps the route', (
        tester,
      ) async {
        final fixture = _expandedFixture(cleanupOnClose: false);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        await startPredictiveBack(tester);
        await commitPredictiveBack(tester);

        _expectPopupClosed(fixture);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('production shell', () {
      testWidgets('fallback back closes the popup and keeps the branch route', (
        tester,
      ) async {
        final fixture = _ShellSearchFixture();
        addTearDown(fixture.dispose);
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(fixture.app);
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SearchBar));
        await tester.pumpAndSettle();
        expect(fixture.controller.isOpen, isTrue);

        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        expect(fixture.controller.isOpen, isFalse);
        expect(find.byType(_SearchHostPage), findsOneWidget);
        expect(fixture.matchedLocation, '/home');
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets(
        'predictive commit closes the popup and keeps the branch route',
        (
          tester,
        ) async {
          final fixture = _ShellSearchFixture();
          addTearDown(fixture.dispose);
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(fixture.app);
          await tester.pumpAndSettle();

          await tester.tap(find.byType(SearchBar));
          await tester.pumpAndSettle();
          expect(fixture.controller.isOpen, isTrue);

          await startPredictiveBack(tester);
          await commitPredictiveBack(tester);

          expect(fixture.controller.isOpen, isFalse);
          expect(find.byType(_SearchHostPage), findsOneWidget);
          expect(fixture.matchedLocation, '/home');
          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    });

    group('close cleanup', () {
      testWidgets('runs exactly once for fallback back', (tester) async {
        final fixture = _compactFixture(cleanupOnClose: true);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        fixture.controller.text = 'molise';
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();

        expect(fixture.closeCleanupCount, 1);
        expect(fixture.controller.text, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('runs exactly once for the leading button', (tester) async {
        final fixture = _compactFixture(cleanupOnClose: true);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        fixture.controller.text = 'molise';
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(fixture.closeCleanupCount, 1);
        expect(fixture.controller.text, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('runs exactly once for barrier dismissal', (tester) async {
        final fixture = _expandedFixture(cleanupOnClose: true);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        fixture.controller.text = 'molise';
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        await tester.tapAt(const Offset(640, 1500));
        await tester.pumpAndSettle();

        expect(fixture.closeCleanupCount, 1);
        expect(fixture.controller.text, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      });

      testWidgets('runs exactly once for programmatic close', (tester) async {
        final fixture = _compactFixture(cleanupOnClose: true);
        addTearDown(fixture.dispose);
        await fixture.pumpApp(tester);
        await _openSearch(tester, fixture);

        fixture.controller.text = 'molise';
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump();
        fixture.controller.closeView(null);
        await tester.pumpAndSettle();

        expect(fixture.closeCleanupCount, 1);
        expect(fixture.controller.text, isEmpty);
        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('viewOnSubmitted unmount race', () {
      // Swallows the debug-only "deactivated widget's ancestor" diagnostic
      // that the framework emits during the deactivation window. This is
      // not a real error — it does not appear in release mode — and would
      // otherwise cause takeException to report a false failure.
      void installDiagnosticFilter() {
        final previousErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.exception.toString().startsWith(
            "Looking up a deactivated widget's ancestor is unsafe.",
          )) {
            return;
          }
          previousErrorHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousErrorHandler);
      }

      testWidgets(
        'submission that goNamed-unmounts the anchor does not crash during '
        'the popup exit transition',
        (tester) async {
          installDiagnosticFilter();

          final fixture = _ShellSearchFixture(navigateOnSubmit: true);
          addTearDown(fixture.dispose);
          await fixture.pumpApp(tester);

          // Open the search view.
          await tester.tap(find.byType(SearchBar));
          await tester.pumpAndSettle();
          expect(fixture.controller.isOpen, isTrue);

          // Enter a valid query and let the debouncer settle.
          fixture.controller.text = 'molise';
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();

          // Drive the framework's real viewOnSubmitted path with ONE call.
          // The view's SearchBar.onSubmitted is wired to SearchAnchor's
          // viewOnSubmitted, which performs addToPastSearches -> closeView
          // (pop + 600 ms exit transition) -> widget.onSubmitted (goNamed
          // -> unmount anchor) in production order. The anchor's own
          // SearchBar (find .first) has no onSubmitted; the view's
          // (find .last) does.
          final viewBar = tester.widget<SearchBar>(
            find.byType(SearchBar).last,
          );
          viewBar.onSubmitted!('molise');

          // Process the pop + goNamed, then run every popup exit-transition
          // tick — each tick re-invokes viewBuilder on the now-dead anchor
          // State. The 600 ms popup exit outlives the ~300 ms route pop, so
          // post-unmount ticks are guaranteed.
          await tester.pump();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(fixture.matchedLocation, '/home/search_results');
          debugDefaultTargetPlatformOverride = null;
        },
      );

      testWidgets(
        'suggestionsBuilder does not crash when re-invoked after unmount',
        (tester) async {
          installDiagnosticFilter();

          final fixture = _ShellSearchFixture(
            navigateOnSubmit: true,
            pastSearches: const ['termoli'],
          );
          addTearDown(fixture.dispose);
          await fixture.pumpApp(tester);

          // Open the search view — a history chip is visible.
          await tester.tap(find.byType(SearchBar));
          await tester.pumpAndSettle();
          expect(fixture.controller.isOpen, isTrue);
          expect(find.text('termoli'), findsOneWidget);

          // Capture the suggestionsBuilder closure and a valid context
          // before unmounting the anchor.
          final searchAnchor = tester.widget<SearchAnchor>(
            find.byType(SearchAnchor),
          );
          final suggestionsBuilder = searchAnchor.suggestionsBuilder;
          final callbackContext = tester.element(find.byType(MaterialApp));

          // Submit → closeView (pop + 600 ms exit transition) → goNamed
          // (page replacement via ValueKey(query) → unmount old anchor).
          final viewBar = tester.widget<SearchBar>(find.byType(SearchBar).last);
          viewBar.onSubmitted!('molise');

          // Process the pop + goNamed + unmount. Pump enough frames for
          // the element to be fully unmounted (_widget = null, mounted =
          // false).
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          // Directly re-invoke the captured suggestionsBuilder on the
          // dead anchor State — this mirrors what the popup view's
          // SearchController listener would do if the text changed.
          // Without the mounted guard at the top of the closure,
          // widget.viewModel throws the null-check TypeError.
          await suggestionsBuilder(callbackContext, fixture.controller);

          // Complete the exit transition.
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(fixture.matchedLocation, '/home/search_results');
          debugDefaultTargetPlatformOverride = null;
        },
      );

      testWidgets(
        'debounce-window submission does not crash when _search runs after '
        'the page is replaced',
        (tester) async {
          installDiagnosticFilter();

          final fixture = _ShellSearchFixture(navigateOnSubmit: true);
          addTearDown(fixture.dispose);
          await fixture.pumpApp(tester);

          // Open the search view.
          await tester.tap(find.byType(SearchBar));
          await tester.pumpAndSettle();
          expect(fixture.controller.isOpen, isTrue);

          // Type a valid query — this starts the 500 ms debounce timer via
          // _debouncedSearch inside suggestionsBuilder. Pump one frame to
          // ensure the async chain (listener → updateSuggestions →
          // suggestionsBuilder → _debouncedSearch → Timer(500ms)) is fully
          // processed and the timer is pending.
          fixture.controller.text = 'molise';
          await tester.pump();

          // Submit within the 500 ms debounce window — viewOnSubmitted →
          // closeView (pop + 600 ms exit transition) → goNamed (page
          // replacement → unmount anchor). The debounce timer is still
          // pending.
          final viewBar = tester.widget<SearchBar>(find.byType(SearchBar).last);
          viewBar.onSubmitted!('molise');

          // Process the pop + goNamed + unmount.
          await tester.pump();

          // Pump past the 500 ms debounce timer. The timer fires and calls
          // _search on the dead anchor State. Without the mounted guard at
          // the top of _search, widget.viewModel throws the null-check
          // TypeError.
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();

          // Complete the exit transition.
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          debugDefaultTargetPlatformOverride = null;
        },
      );
    });
  });

  group('SearchResultScreen canonical query', () {
    ({GoRouter router, SearchViewModel viewModel, Widget app}) buildFixture() {
      final viewModel = SearchViewModel(
        eventRepository: FakeEventRepository(),
        exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(),
        searchRepository: _FakeSearchRepository(),
      );
      final router = GoRouter(
        initialLocation: '/home/search_results?q=old',
        routes: <RouteBase>[
          GoRoute(
            path: '/home/search_results',
            name: RouteNames.homeSearchResult,
            builder: (_, state) => SearchResultScreen(
              query: state.uri.queryParameters['q'] ?? '',
              viewModel: viewModel,
            ),
          ),
        ],
      );
      return (
        router: router,
        viewModel: viewModel,
        app: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('submission updates the canonical q URI', (tester) async {
      final fixture = buildFixture();
      addTearDown(fixture.router.dispose);
      addTearDown(fixture.viewModel.dispose);
      await fixture.viewModel.loadResults.execute('old');
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      tester.widget<AppSearchAnchor>(find.byType(AppSearchAnchor)).onSubmitted!(
        'new query',
      );
      await tester.pumpAndSettle();

      expect(
        fixture.router.routeInformationProvider.value.uri.queryParameters['q'],
        'new query',
      );
      expect(
        tester
            .widget<SearchResultScreen>(find.byType(SearchResultScreen))
            .query,
        'new query',
      );
    });

    testWidgets('suggestion uses its content name as the canonical q', (
      tester,
    ) async {
      final fixture = buildFixture();
      addTearDown(fixture.router.dispose);
      addTearDown(fixture.viewModel.dispose);
      await fixture.viewModel.loadResults.execute('old');
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      tester
          .widget<AppSearchAnchor>(find.byType(AppSearchAnchor))
          .onSuggestionPressed(makePlace(name: 'Castello Monforte'));
      await tester.pumpAndSettle();

      expect(
        fixture.router.routeInformationProvider.value.uri.queryParameters['q'],
        'Castello Monforte',
      );
      expect(find.byType(SearchResultScreen), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

Future<void> _openSearch(WidgetTester tester, _SearchFixture fixture) async {
  await tester.tap(find.text('Open search'));
  await tester.pumpAndSettle();

  expect(find.byType(_SearchHostPage), findsOneWidget);
  expect(fixture.matchedLocation, '/search');

  await tester.tap(find.byType(SearchBar));
  await tester.pumpAndSettle();

  expect(fixture.controller.isOpen, isTrue);
  expect(fixture.matchedLocation, '/search');
}

void _expectPopupClosed(_SearchFixture fixture) {
  expect(fixture.controller.isOpen, isFalse);
  expect(find.byType(_SearchHostPage), findsOneWidget);
  expect(fixture.matchedLocation, '/search');
  expect(fixture.uri.path, '/');
}

_SearchFixture _compactFixture({required bool cleanupOnClose}) {
  return _SearchFixture(
    cleanupOnClose: cleanupOnClose,
    surfaceSize: const Size(390, 844),
  );
}

_SearchFixture _expandedFixture({required bool cleanupOnClose}) {
  return _SearchFixture(
    cleanupOnClose: cleanupOnClose,
    surfaceSize: const Size(1280, 1600),
  );
}

// ---------------------------------------------------------------------------
// Fixture
// ---------------------------------------------------------------------------

final class _SearchFixture {
  _SearchFixture({
    required bool cleanupOnClose,
    required Size surfaceSize,
  }) : _surfaceSize = surfaceSize {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    controller = SearchController();
    viewModel = SearchViewModel(
      eventRepository: FakeEventRepository(),
      exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(),
      searchRepository: _FakeSearchRepository(),
    );
    router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, _) => const _HomePage(),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (_, _) => _SearchHostPage(
            controller: controller,
            viewModel: viewModel,
            onBackPressed: cleanupOnClose
                ? () {
                    closeCleanupCount++;
                    controller.clear();
                  }
                : null,
          ),
        ),
      ],
    );
  }

  late final SearchController controller;
  late final SearchViewModel viewModel;
  final Size _surfaceSize;
  late final GoRouter router;
  int closeCleanupCount = 0;

  Uri get uri => router.routeInformationProvider.value.uri;

  String get matchedLocation =>
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation;

  Widget get app => MaterialApp.router(routerConfig: router);

  /// Pins the window surface to the fixture size and pumps the app.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(_surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  void dispose() {
    debugDefaultTargetPlatformOverride = null;
    controller.dispose();
    viewModel.dispose();
    router.dispose();
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.pushNamed('search'),
          child: const Text('Open search'),
        ),
      ),
    );
  }
}

/// Shell-based fixture that mirrors the production `StatefulShellRoute`
/// topology with all four branches so the search popup receives Router back
/// inside a branch and hidden branches behave exactly as in production.
///
/// When [navigateOnSubmit] is true, the fixture starts at
/// `/home/search_results?q=initial` — matching the production
/// `SearchResultScreen` flow where the anchor lives on the results page.
/// Submitting calls `goNamed` to the same route with a different `q`
/// parameter, which replaces the page (via `ValueKey(query)`) and unmounts
/// the old anchor while the popup view is still fading out.
final class _ShellSearchFixture {
  _ShellSearchFixture({
    this.navigateOnSubmit = false,
    List<String> pastSearches = const [],
  }) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    controller = SearchController();
    viewModel = SearchViewModel(
      eventRepository: FakeEventRepository(),
      exploreGetByIdUseCase: _FakeExploreGetByIdUseCase(),
      searchRepository: _FakeSearchRepository(pastSearches: pastSearches),
    );
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: navigateOnSubmit
          ? '/home/search_results?q=initial'
          : '/home',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              navigatorKey: exploreNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: '/home',
                  builder: (_, _) => _SearchHostPage(
                    controller: controller,
                    viewModel: viewModel,
                  ),
                  // Production declares /home/search_results as a child of
                  // /home with parentNavigatorKey: rootNavigatorKey, so the
                  // results page pushes on the root navigator. The child
                  // path is relative ('search_results'), matching
                  // RoutePaths. The results page has ValueKey(query) —
                  // matching SearchResultScreen's wrapper in router.dart —
                  // so goNamed to the same route with a different q
                  // replaces the page and unmounts the old anchor.
                  routes: <RouteBase>[
                    GoRoute(
                      parentNavigatorKey: rootNavigatorKey,
                      path: 'search_results',
                      name: RouteNames.homeSearchResult,
                      builder: (_, state) => _SearchHostPage(
                        key: ValueKey(state.uri.queryParameters['q'] ?? ''),
                        controller: controller,
                        viewModel: viewModel,
                        navigateOnSubmit: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: favouritesNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: '/favourites',
                  builder: (_, _) => const _StubBranchPage(label: 'Favourites'),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: eventsNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: '/events',
                  builder: (_, _) => const _StubBranchPage(label: 'Events'),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: mapNavigatorKey,
              routes: <RouteBase>[
                GoRoute(
                  path: '/map',
                  builder: (_, _) => const _StubBranchPage(label: 'Map'),
                ),
              ],
            ),
          ],
          builder: (_, _, navigationShell) => navigationShell,
        ),
      ],
    );
  }

  final bool navigateOnSubmit;

  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final exploreNavigatorKey = GlobalKey<NavigatorState>();
  final favouritesNavigatorKey = GlobalKey<NavigatorState>();
  final eventsNavigatorKey = GlobalKey<NavigatorState>();
  final mapNavigatorKey = GlobalKey<NavigatorState>();
  late final SearchController controller;
  late final SearchViewModel viewModel;
  late final GoRouter router;

  Uri get uri => router.routeInformationProvider.value.uri;

  String get matchedLocation =>
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation;

  Widget get app => MaterialApp.router(routerConfig: router);

  /// Pins the window surface to a compact phone size and pumps the app.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  void dispose() {
    debugDefaultTargetPlatformOverride = null;
    controller.dispose();
    viewModel.dispose();
    router.dispose();
  }
}

class _StubBranchPage extends StatelessWidget {
  const _StubBranchPage({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

class _SearchHostPage extends StatelessWidget {
  const _SearchHostPage({
    super.key,
    required this.controller,
    required this.viewModel,
    this.onBackPressed,
    this.navigateOnSubmit = false,
  });

  final SearchController controller;
  final SearchViewModel viewModel;
  final VoidCallback? onBackPressed;
  final bool navigateOnSubmit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: AppSearchAnchor(
            controller: controller,
            onBackPressed: onBackPressed,
            onSubmitted: navigateOnSubmit
                ? (query) {
                    if (query.isEmpty) return;
                    context.goNamed(
                      RouteNames.homeSearchResult,
                      queryParameters: {'q': query},
                    );
                  }
                : (_) {},
            onSuggestionPressed: navigateOnSubmit
                ? (content) {
                    controller.closeView(null);
                    context.goNamed(
                      RouteNames.homeSearchResult,
                      queryParameters: {'q': content.name},
                    );
                  }
                : (_) {},
            viewModel: viewModel,
          ),
        ),
      ),
    );
  }
}

final class _FakeExploreGetByIdUseCase implements ExploreGetByIdUseCase {
  @override
  Future<Result<Place>> getById(int id) async =>
      Result.error(TestException('Place $id not configured'));
}

final class _FakeSearchRepository implements SearchRepository {
  _FakeSearchRepository({this.pastSearches = const []});

  final List<String> pastSearches;

  @override
  Future<Result<void>> addToPastSearches(String text) async =>
      const Result.success(null);

  @override
  Future<Result<List<int>>> getEventIdsByQuery(String text) async =>
      const Result.success([]);

  @override
  Future<Result<List<int>>> getPlaceIdsByQuery(String text) async =>
      const Result.success([]);

  @override
  Future<Result<List<String>>> getPastSearches() async =>
      Result.success(List<String>.of(pastSearches));

  @override
  Future<Result<List<int>>> getRelatedResults(String text) async =>
      const Result.success([]);

  @override
  Future<Result<void>> removeFromPastSearches(String text) async =>
      const Result.success(null);
}
