import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/theme_type.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/main.dart';
import 'package:moliseis/routing/route_names.dart';
import 'package:moliseis/routing/route_paths.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/core/ui/route_error_screen.dart';
import 'package:moliseis/ui/explore/widgets/explore_screen.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/settings/widgets/settings_screen.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/ui/sync/widgets/sync_screen.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../support/fake_cache_manager.dart';
import '../support/fake_repositories.dart';
import '../support/fixtures.dart';
import '../support/mock_gotrue_client.dart';
import '../support/mock_logger.dart';

void main() {
  group('buildAppRouter sync redirect', () {
    testWidgets('unknown route renders the route error screen', (
      tester,
    ) async {
      final harness = _SyncHarness();
      final router = _buildTestRouterApp(harness);

      await tester.pumpWidget(router.app);
      await _pumpRedirects(tester);

      router.router.go('/home/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.byType(RouteErrorScreen), findsOneWidget);
      expect(
        router.router.routeInformationProvider.value.uri.path,
        '/home/does-not-exist',
      );
    });

    testWidgets('cold start without a due sync stays on /home', (
      tester,
    ) async {
      final harness = _SyncHarness();
      final router = _buildTestRouterApp(harness);

      await tester.pumpWidget(router.app);
      await _pumpRedirects(tester);

      expect(router.router.routeInformationProvider.value.uri.path, '/home');
      expect(find.byType(SyncScreen), findsNothing);
    });

    testWidgets('automatic sync from /home preserves /home and returns', (
      tester,
    ) async {
      final harness = _SyncHarness(autoSync: true);
      final router = _buildTestRouterApp(harness);

      await tester.pumpWidget(router.app);
      await _pumpRedirects(tester);

      final uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, RoutePaths.sync);
      expect(uri.queryParameters['from'], RoutePaths.home);

      harness.release();
      await tester.pumpAndSettle();

      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.home,
      );
      expect(find.byType(SyncScreen), findsNothing);
    });

    testWidgets('manual sync from /home preserves /home and returns', (
      tester,
    ) async {
      final harness = _SyncHarness();
      final router = _buildTestRouterApp(harness);

      await tester.pumpWidget(router.app);
      await _pumpRedirects(tester);
      expect(router.router.routeInformationProvider.value.uri.path, '/home');

      unawaited(harness.viewModel.sync.execute(true));
      await _pumpRedirects(tester);

      final uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, RoutePaths.sync);
      expect(uri.queryParameters['from'], RoutePaths.home);

      harness.release();
      await tester.pumpAndSettle();

      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.home,
      );
    });

    testWidgets('sync from a detail URI preserves and restores it', (
      tester,
    ) async {
      final event = makeEvent();
      final eventRepository = FakeEventRepository(
        getByIdResults: <int, Result<Event>>{1: Result.success(event)},
      );
      final harness = _SyncHarness();
      final router = _buildTestRouterApp(
        harness,
        eventRepository: eventRepository,
      );

      await tester.pumpWidget(router.app);
      await _pumpRedirects(tester);

      router.router.goNamed(
        RouteNames.homePost,
        pathParameters: <String, String>{'id': '1'},
        queryParameters: <String, String>{'type': 'event'},
      );
      await _pumpRedirects(tester);

      var uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, '/home/posts/1');
      expect(uri.queryParameters['type'], 'event');

      unawaited(harness.viewModel.sync.execute(true));
      await _pumpRedirects(tester);

      uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, RoutePaths.sync);
      expect(uri.queryParameters['from'], '/home/posts/1?type=event');

      harness.release();
      await tester.pumpAndSettle();

      uri = router.router.routeInformationProvider.value.uri;
      expect(uri.path, '/home/posts/1');
      expect(uri.queryParameters['type'], 'event');
    });

    testWidgets('non-fatal error returns to the preserved URI', (
      tester,
    ) async {
      final harness = _SyncHarness(
        cityResult: Result.error(TestException('sync failed')),
      );
      final router = _buildTestRouterApp(harness);

      await tester.pumpWidget(router.app);
      await _pumpRedirects(tester);

      unawaited(harness.viewModel.sync.execute(true));
      await _pumpRedirects(tester);
      expect(router.router.routeInformationProvider.value.uri.path, '/sync');

      harness.release();
      await _pumpRedirects(tester);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.home,
      );
      expect(
        find.text(
          "Si è verificato un errore durante l'aggiornamento dei contenuti",
        ),
        findsOneWidget,
      );
    });

    testWidgets('fatal first-sync error remains on /sync', (tester) async {
      final harness = _SyncHarness(
        autoSync: true,
        cityResult: Result.error(TestException('sync failed')),
      );
      final router = _buildTestRouterApp(harness);

      await tester.pumpWidget(router.app);
      await _pumpRedirects(tester);
      expect(router.router.routeInformationProvider.value.uri.path, '/sync');

      harness.release();
      await tester.pumpAndSettle();

      expect(
        router.router.routeInformationProvider.value.uri.path,
        RoutePaths.sync,
      );
      expect(
        find.textContaining(
          'Molise Is necessita di una connessione ad internet',
        ),
        findsOneWidget,
      );
    });

    for (final from in _invalidFromValues) {
      testWidgets(
        'rejects invalid from value "$from" and falls back to /home',
        (
          tester,
        ) async {
          final harness = _SyncHarness();
          final router = _buildTestRouterApp(harness);

          await tester.pumpWidget(router.app);
          await _pumpRedirects(tester);

          // Keep the command running while substituting the crafted value.
          unawaited(harness.viewModel.sync.execute(true));
          await _pumpRedirects(tester);

          router.router.go(
            '${RoutePaths.sync}?from=${Uri.encodeComponent(from)}',
          );
          await _pumpRedirects(tester);
          expect(
            router.router.routeInformationProvider.value.uri.path,
            '/sync',
          );

          harness.release();
          await tester.pumpAndSettle();

          expect(
            router.router.routeInformationProvider.value.uri.path,
            RoutePaths.home,
          );
        },
      );
    }

    testWidgets(
      'sync restores an admin user to /admin after completing',
      (tester) async {
        final auth = ControllableAdminAuth(
          initialUser: makeAuthUser(isAdmin: true),
        );
        final harness = _SyncHarness();
        final router = _buildTestRouterApp(harness, auth: auth);

        router.router.go(RoutePaths.admin);
        unawaited(harness.viewModel.sync.execute(true));
        await tester.pumpWidget(router.app);
        await _pumpRedirects(tester);

        final syncUri = router.router.routeInformationProvider.value.uri;
        expect(syncUri.path, RoutePaths.sync);
        expect(syncUri.queryParameters['from'], RoutePaths.admin);

        harness.release();
        await _pumpRedirects(tester);

        expect(
          router.router.routeInformationProvider.value.uri.path,
          RoutePaths.admin,
        );
      },
    );

    testWidgets(
      'sync restores an anonymous user to /admin/login after completing',
      (tester) async {
        final auth = ControllableAdminAuth();
        final harness = _SyncHarness();
        final router = _buildTestRouterApp(harness, auth: auth);

        router.router.go(RoutePaths.admin);
        unawaited(harness.viewModel.sync.execute(true));
        await tester.pumpWidget(router.app);
        await _pumpRedirects(tester);

        final syncUri = router.router.routeInformationProvider.value.uri;
        expect(syncUri.path, RoutePaths.sync);
        expect(syncUri.queryParameters['from'], RoutePaths.admin);

        harness.release();
        await _pumpRedirects(tester);

        expect(
          router.router.routeInformationProvider.value.uri.path,
          RoutePaths.adminLoginLocation,
        );
      },
    );
  });

  group('buildAppRouter sync restoration', () {
    testWidgets(
      'restored idle /sync returns to the preserved settings URI',
      (tester) async {
        // Persist a recent timestamp so the fresh view model skips auto-sync.
        final settings = FakeSettingsRepository(lastSyncedAt: DateTime.now());
        final holder = _SyncRestorationHolder(
          settingsFactory: () => settings,
        );

        await tester.pumpWidget(_RestorableSyncHarness(holder: holder));
        await _pumpRedirects(tester);
        final before = holder.fixture!;

        before.router.go(RoutePaths.settings);
        await _pumpRedirects(tester);
        expect(
          before.router.routeInformationProvider.value.uri.path,
          RoutePaths.settings,
        );

        unawaited(before.harness.viewModel.sync.execute(true));
        await _pumpRedirects(tester);
        expect(
          before.router.routeInformationProvider.value.uri.path,
          RoutePaths.sync,
        );
        expect(
          before
              .router
              .routeInformationProvider
              .value
              .uri
              .queryParameters['from'],
          RoutePaths.settings,
        );

        await tester.restartAndRestore();
        await _pumpRedirects(tester);

        final after = holder.fixture!;
        expect(after, isNot(same(before)));
        expect(after.harness.viewModel, isNot(same(before.harness.viewModel)));
        expect(after.harness.viewModel.sync.idle, isTrue);
        expect(
          after.router.routeInformationProvider.value.uri.path,
          RoutePaths.settings,
        );
        expect(find.byType(SyncScreen), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'restored due sync remains on /sync until it completes',
      (tester) async {
        final holder = _SyncRestorationHolder(
          // Each fixture needs its own settings so completing the old gated
          // sync cannot make the fresh view model think it is up to date.
          settingsFactory: FakeSettingsRepository.new,
        );

        await tester.pumpWidget(_RestorableSyncHarness(holder: holder));
        await _pumpRedirects(tester);
        final before = holder.fixture!;
        expect(before.harness.viewModel.sync.running, isTrue);
        expect(
          before.router.routeInformationProvider.value.uri.path,
          RoutePaths.sync,
        );
        expect(
          before
              .router
              .routeInformationProvider
              .value
              .uri
              .queryParameters['from'],
          RoutePaths.home,
        );

        await tester.restartAndRestore();
        await _pumpRedirects(tester);

        final after = holder.fixture!;
        expect(after, isNot(same(before)));
        expect(after.harness.viewModel.sync.running, isTrue);
        expect(
          after.router.routeInformationProvider.value.uri.path,
          RoutePaths.sync,
        );
        expect(
          after
              .router
              .routeInformationProvider
              .value
              .uri
              .queryParameters['from'],
          RoutePaths.home,
        );
        expect(find.byType(SyncScreen), findsOneWidget);

        after.harness.release();
        await tester.pumpAndSettle();

        expect(
          after.router.routeInformationProvider.value.uri.path,
          RoutePaths.home,
        );
        expect(find.byType(SyncScreen), findsNothing);
      },
    );
  });

  group('MoliseIsApp router lifecycle', () {
    testWidgets('theme rebuild keeps the same router and URI', (tester) async {
      final harness = _SyncHarness();
      await tester.pumpWidget(_buildRealApp(harness));
      await tester.pumpAndSettle();

      final exploreContext = tester.element(find.byType(ExploreScreen));
      final routerBefore = GoRouter.of(exploreContext);

      exploreContext.goNamed(RouteNames.settings);
      await tester.pumpAndSettle();

      final settingsContext = tester.element(find.byType(SettingsScreen));
      expect(
        routerBefore.routeInformationProvider.value.uri.path,
        RoutePaths.settings,
      );

      await settingsContext.read<ThemeViewModel>().setThemeType.execute(
        ThemeType.app,
      );
      await tester.pumpAndSettle();

      expect(GoRouter.of(settingsContext), same(routerBefore));
      expect(
        routerBefore.routeInformationProvider.value.uri.path,
        RoutePaths.settings,
      );
    });
  });
}

/// Values that must never be honored as a sync `from` target.
const List<String> _invalidFromValues = <String>[
  'https://evil.example/private',
  '//evil.example/private',
  'javascript:alert(1)',
  'posts/1?type=event',
  '/sync',
  '/sync?from=%2Fhome',
  '/home/does-not-exist',
];

/// Pumps enough frames for the asynchronous sync redirect chain to complete
/// without settling on the indeterminate loading spinner.
Future<void> _pumpRedirects(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump();
  }
}

/// A [SyncViewModel] whose running sync is controlled through [gate].
final class _SyncHarness {
  _SyncHarness({
    bool autoSync = false,
    bool gated = true,
    FakeSettingsRepository? settings,
    Result<List<CityDto>> cityResult = const Result.success(<CityDto>[]),
  }) {
    gate = gated ? Completer<void>() : null;
    this.settings =
        settings ??
        FakeSettingsRepository(lastSyncedAt: autoSync ? null : DateTime.now());
    final useCase = SyncUseCase(
      cityRepository: _GatedCityRepository(
        gate: gate,
        prepareResult: cityResult,
      ),
      eventRepository: FakeEventRepository(),
      mediaRepository: FakeMediaRepository(),
      placeRepository: FakePlaceRepository(),
      settingsRepository: this.settings,
      transactionCoordinator: FakeTransactionCoordinator(),
    );
    viewModel = SyncViewModel(syncUseCase: useCase);
  }

  Completer<void>? gate;
  late final FakeSettingsRepository settings;
  late final SyncViewModel viewModel;

  void release() {
    gate?.complete();
  }
}

/// Rebuilds the production router with a fresh [SyncViewModel] on restoration.
final class _SyncRestorationFixture {
  _SyncRestorationFixture({required FakeSettingsRepository settings}) {
    harness = _SyncHarness(settings: settings);
    auth = ControllableAdminAuth();
    router = buildAppRouter(
      syncViewModel: harness.viewModel,
      adminAuthViewModel: auth.viewModel,
    );
  }

  late final ControllableAdminAuth auth;
  late final _SyncHarness harness;
  late final GoRouter router;

  Widget get app => MultiProvider(
    providers: _buildProviders(harness, auth: auth),
    child: MaterialApp.router(
      scaffoldMessengerKey: $scaffoldMessengerKey,
      restorationScopeId: 'app',
      routerConfig: router,
    ),
  );

  void dispose() {
    router.dispose();
    auth.dispose();

    final sync = harness.viewModel.sync;
    if (!sync.running) {
      harness.viewModel.dispose();
      return;
    }

    void disposeWhenComplete() {
      if (sync.running) return;

      sync.removeListener(disposeWhenComplete);
      scheduleMicrotask(harness.viewModel.dispose);
    }

    // Detach the router before unblocking the command. It may notify while
    // completing, so dispose the view model only after that notification.
    sync.addListener(disposeWhenComplete);
    final gate = harness.gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

/// Holds test state that can either persist or be recreated on restoration.
final class _SyncRestorationHolder {
  _SyncRestorationHolder({required this.settingsFactory});

  final FakeSettingsRepository Function() settingsFactory;
  _SyncRestorationFixture? fixture;
}

class _RestorableSyncHarness extends StatefulWidget {
  const _RestorableSyncHarness({required this.holder});

  final _SyncRestorationHolder holder;

  @override
  State<_RestorableSyncHarness> createState() => _RestorableSyncHarnessState();
}

class _RestorableSyncHarnessState extends State<_RestorableSyncHarness> {
  late final _SyncRestorationFixture fixture = _SyncRestorationFixture(
    settings: widget.holder.settingsFactory(),
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

/// Gates the city preparation so the whole sync is observable as running.
final class _GatedCityRepository extends CityRepository {
  _GatedCityRepository({required this.gate, required this.prepareResult});

  final Completer<void>? gate;
  final Result<List<CityDto>> prepareResult;

  @override
  Future<Result<List<CityDto>>> prepareSync() async {
    if (gate != null) {
      await gate!.future;
    }
    return prepareResult;
  }

  @override
  Result<void> commitSync(List<CityDto> dtos) => const Result.success(null);
}

/// A [SearchRepository] fake that never surfaces persisted data.
final class _FakeSearchRepository implements SearchRepository {
  @override
  Future<Result<void>> addToPastSearches(String text) async =>
      const Result.success(null);

  @override
  Future<Result<List<int>>> getEventIdsByQuery(String text) async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getPlaceIdsByQuery(String text) async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<int>>> getRelatedResults(String text) async =>
      const Result.success(<int>[]);

  @override
  Future<Result<List<String>>> getPastSearches() async =>
      const Result.success(<String>[]);

  @override
  Future<Result<void>> removeFromPastSearches(String text) async =>
      const Result.success(null);
}

/// Builds the production router with the full provider tree the real screens
/// require, plus the controlled [harness] sync view model.
({GoRouter router, Widget app, ControllableAdminAuth auth}) _buildTestRouterApp(
  _SyncHarness harness, {
  FakeEventRepository? eventRepository,
  ControllableAdminAuth? auth,
}) {
  final authHarness = auth ?? ControllableAdminAuth();
  final router = buildAppRouter(
    syncViewModel: harness.viewModel,
    adminAuthViewModel: authHarness.viewModel,
  );
  addTearDown(authHarness.dispose);
  addTearDown(router.dispose);

  final app = MultiProvider(
    providers: _buildProviders(
      harness,
      auth: authHarness,
      eventRepository: eventRepository,
    ),
    child: MaterialApp.router(
      scaffoldMessengerKey: $scaffoldMessengerKey,
      routerConfig: router,
    ),
  );

  return (router: router, app: app, auth: authHarness);
}

/// Builds the production app root so the router lifecycle under theme rebuilds
/// is exercised exactly as shipped.
Widget _buildRealApp(_SyncHarness harness) {
  final auth = ControllableAdminAuth();
  addTearDown(auth.dispose);

  return MultiProvider(
    providers: _buildProviders(harness, auth: auth),
    child: const MoliseIsApp(),
  );
}

/// The providers the real screens resolved from the router tree require.
List<SingleChildWidget> _buildProviders(
  _SyncHarness harness, {
  required ControllableAdminAuth auth,
  FakeEventRepository? eventRepository,
}) {
  final eventRepo = eventRepository ?? FakeEventRepository();
  final placeRepo = FakePlaceRepository();
  final logger = MockLogger();
  final weatherApiClient = CachedWeatherApiClient(
    weatherApiClient: FakeWeatherApiClient(),
    currentWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<CurrentWeatherForecastData>
        >(
          maxSize: 8,
        ),
    hourlyWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<HourlyWeatherForecastData>
        >(
          maxSize: 8,
        ),
    dailyWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<DailyWeatherForecastData>
        >(
          maxSize: 8,
        ),
    logger: logger,
  );
  final settingsRepository = FakeSettingsRepository();

  return <SingleChildWidget>[
    Provider<AdminContentSubmissionRepository>.value(
      value: FakeAdminContentSubmissionRepository(),
    ),
    Provider<EventRepository>.value(value: eventRepo),
    Provider<PlaceRepository>.value(value: placeRepo),
    Provider<SearchRepository>.value(value: _FakeSearchRepository()),
    Provider<SettingsRepository>.value(value: settingsRepository),
    Provider<CachedWeatherApiClient>.value(value: weatherApiClient),
    Provider<CacheManager>.value(value: FakeCacheManager()),
    Provider<Logger>.value(value: logger),
    Provider<UrlLaunchService>(
      create: (_) => UrlLaunchService(logger: logger),
    ),
    ChangeNotifierProvider<FavouriteViewModel>(
      create: (_) => FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: eventRepo,
          placeRepository: placeRepo,
        ),
      ),
    ),
    ChangeNotifierProvider<ThemeViewModel>(
      create: (_) => ThemeViewModel(settingsRepository: settingsRepository),
    ),
    ChangeNotifierProvider<SettingsViewModel>(
      create: (_) => SettingsViewModel(
        settingsRepository: settingsRepository,
        sentryLoggingFlag: SentryLoggingFlag(initialValue: false),
      ),
    ),
    ChangeNotifierProvider<SyncViewModel>.value(value: harness.viewModel),
    ChangeNotifierProvider<AdminAuthViewModel>.value(
      value: auth.viewModel,
    ),
  ];
}
