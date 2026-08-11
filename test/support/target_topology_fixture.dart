import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/domain/models/media.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/ui/core/ui/scaffold_shell.dart';
import 'package:moliseis/ui/gallery/models/gallery_preview_route_data.dart';
import 'package:moliseis/ui/gallery/widgets/gallery_preview_screen.dart';
import 'package:provider/provider.dart';

/// Test-only router that mirrors the production route ownership and shell.
///
/// The Explore, Favourites, Events, and Map branches each own exactly one root
/// page through [StatefulShellRoute.indexedStack]. The detail page is a nested
/// route under the Explore root whose page is placed on the root Navigator
/// through `parentNavigatorKey`, and the gallery is a root-owned top-level
/// route whose builder mirrors the production gallery route. The shell is the
/// production [ScaffoldShell], so tab selection and active-tab reset behave
/// exactly as shipped. The fixture intentionally uses no application back
/// state: no `GalleryPreviewScreen.isOpen`, no branch `PopScope`, no
/// `LocalHistoryEntry`, and no direct platform back-ownership call.
///
/// Predictive-back gesture channel messages are only handled by the Android
/// page-transitions builder, so tests that use the predictive helpers must pin
/// `debugDefaultTargetPlatformOverride` to `TargetPlatform.android` themselves
/// and restore it before the test body ends (the framework's debug-variable
/// invariant runs before teardowns). Pass a [CacheManager] when a test opens
/// the real gallery, which resolves network images through the provider.
/// [dispose] disposes the router.
final class TargetTopologyFixture {
  TargetTopologyFixture({
    String initialLocation = '/home',
    CacheManager? cacheManager,
  }) : _cacheManager = cacheManager {
    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      restorationScopeId: 'router',
      routes: <RouteBase>[
        GoRoute(
          path: '/gallery',
          name: RouteNames.gallery,
          builder: (_, state) {
            final data = GalleryPreviewRouteData.tryParse(state.extra);
            return data == null
                ? const GalleryUnavailableScreen()
                : GalleryPreviewScreen(data: data);
          },
        ),
        GoRoute(
          path: '/destination',
          builder: (_, _) => const _DestinationPage(),
        ),
        StatefulShellRoute.indexedStack(
          restorationScopeId: 'appShell',
          pageBuilder: (_, _, navigationShell) => MaterialPage<void>(
            restorationId: 'appShellPage',
            child: ScaffoldShell(navigationShell: navigationShell),
          ),
          branches: <StatefulShellBranch>[
            _branch(
              navigatorKey: exploreNavigatorKey,
              restorationScopeId: 'exploreBranch',
              path: '/home',
              label: 'Explore',
              nestedRoutes: <RouteBase>[
                GoRoute(
                  path: 'detail',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (_, _) => const _DetailPage(),
                ),
              ],
            ),
            _branch(
              navigatorKey: favouritesNavigatorKey,
              restorationScopeId: 'favouritesBranch',
              path: '/favourites',
              label: 'Favourites',
            ),
            _branch(
              navigatorKey: eventsNavigatorKey,
              restorationScopeId: 'eventsBranch',
              path: '/events',
              label: 'Events',
            ),
            _branch(
              navigatorKey: mapNavigatorKey,
              restorationScopeId: 'mapBranch',
              path: '/map',
              label: 'Map',
              pageBuilder: () => const _MapBranchPage(),
            ),
          ],
        ),
      ],
    );
  }

  final CacheManager? _cacheManager;

  /// The root Navigator key that owns the shell page and the secondary pages.
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  /// The Explore branch Navigator key.
  final exploreNavigatorKey = GlobalKey<NavigatorState>();

  /// The Favourites branch Navigator key.
  final favouritesNavigatorKey = GlobalKey<NavigatorState>();

  /// The Events branch Navigator key.
  final eventsNavigatorKey = GlobalKey<NavigatorState>();

  /// The Map branch Navigator key.
  final mapNavigatorKey = GlobalKey<NavigatorState>();

  /// The fixture router, created in the constructor.
  late final GoRouter router;

  /// The currently matched application URI.
  Uri get uri => router.routeInformationProvider.value.uri;

  /// The matched location of the most recent route match.
  ///
  /// Unlike [uri], this reflects routes pushed with `push` or `pushNamed`,
  /// whose location is not part of the router's canonical URI until the pushed
  /// route pops.
  String get matchedLocation =>
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation;

  /// All branch Navigator keys in tab order.
  List<GlobalKey<NavigatorState>> get branchNavigatorKeys =>
      <GlobalKey<NavigatorState>>[
        exploreNavigatorKey,
        favouritesNavigatorKey,
        eventsNavigatorKey,
        mapNavigatorKey,
      ];

  /// Builds the fixture application around [router].
  ///
  /// When a [CacheManager] was provided, the app is wrapped in a
  /// `Provider<CacheManager>` so the real gallery resolves network images.
  Widget get app {
    final routerApp = MaterialApp.router(
      routerConfig: router,
      restorationScopeId: 'app',
    );
    final cacheManager = _cacheManager;
    return cacheManager == null
        ? routerApp
        : Provider<CacheManager>.value(
            value: cacheManager,
            child: routerApp,
          );
  }

  /// Disposes the router.
  void dispose() {
    router.dispose();
  }
}

StatefulShellBranch _branch({
  required GlobalKey<NavigatorState> navigatorKey,
  required String restorationScopeId,
  required String path,
  required String label,
  List<RouteBase> nestedRoutes = const <RouteBase>[],
  Widget Function()? pageBuilder,
}) => StatefulShellBranch(
  navigatorKey: navigatorKey,
  restorationScopeId: restorationScopeId,
  routes: <RouteBase>[
    GoRoute(
      path: path,
      builder: (_, _) =>
          pageBuilder != null ? pageBuilder() : _BranchRootPage(label: label),
      routes: nestedRoutes,
    ),
  ],
);

/// Root-owned detail page that opens the root-owned gallery.
class _DetailPage extends StatelessWidget {
  const _DetailPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Detail page'),
            FilledButton(
              onPressed: () async {
                await GalleryPreviewScreen.show(
                  context: context,
                  media: [_buildMedia()],
                  initialIndex: 0,
                );
              },
              child: const Text('Open gallery'),
            ),
            FilledButton(
              onPressed: () async {
                await GalleryPreviewScreen.show(
                  context: context,
                  media: _buildMultiMedia(),
                  initialIndex: 2,
                );
              },
              child: const Text('Open gallery on page 3'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Root-owned destination page used by replacement tests.
class _DestinationPage extends StatelessWidget {
  const _DestinationPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Destination')));
  }
}

/// Map branch root with the same local state as the other branch roots plus a
/// gallery opener, mirroring the production map tab which opens the gallery
/// from selected content.
class _MapBranchPage extends StatefulWidget {
  const _MapBranchPage();

  @override
  State<_MapBranchPage> createState() => _MapBranchPageState();
}

class _MapBranchPageState extends State<_MapBranchPage> {
  var _count = 0;

  void _increment() => setState(() => _count++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Map root'),
            Text('Count: $_count'),
            FilledButton(
              onPressed: _increment,
              child: const Text('Increment Map'),
            ),
            FilledButton(
              onPressed: () async {
                await GalleryPreviewScreen.show(
                  context: context,
                  media: [_buildMedia()],
                  initialIndex: 0,
                );
              },
              child: const Text('Open map gallery'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Branch root page with local state used to prove branch persistence.
class _BranchRootPage extends StatefulWidget {
  const _BranchRootPage({required this.label});

  /// The human-readable branch name shown in the page and its controls.
  final String label;

  @override
  State<_BranchRootPage> createState() => _BranchRootPageState();
}

class _BranchRootPageState extends State<_BranchRootPage> {
  var _count = 0;

  void _increment() => setState(() => _count++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('${widget.label} root'),
            Text('Count: $_count'),
            FilledButton(
              onPressed: _increment,
              child: Text('Increment ${widget.label}'),
            ),
          ],
        ),
      ),
    );
  }
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

/// Four-item media list used by the multi-page restoration test.
///
/// Each item has a distinct [Media.remoteId] and [Media.url] so a restored
/// gallery can be pinned to a specific page.
List<Media> _buildMultiMedia() => <Media>[
  _buildMediaWith(id: 1, title: 'First'),
  _buildMediaWith(id: 2, title: 'Second'),
  _buildMediaWith(id: 3, title: 'Third'),
  _buildMediaWith(id: 4, title: 'Fourth'),
];

/// Single [Media] with a distinct [Media.remoteId] and [Media.url].
Media _buildMediaWith({required int id, String? title}) => Media(
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
