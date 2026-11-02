import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/domain/repositories/admin_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/main.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/admin/submissions/view_models/admin_submission_editor_view_model.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/ui/sync/widgets/sync_screen.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'admin_draft_repositories.dart';
import 'crash_reporting_support.dart';
import 'fake_cache_manager.dart';
import 'fake_repositories.dart';
import 'mock_gotrue_client.dart';
import 'mock_logger.dart';
import 'recording_tile_http_client.dart';

/// Pumps enough frames for the asynchronous sync redirect chain to complete
/// without settling on the indeterminate loading spinner.
Future<void> pumpSyncRedirects(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(Duration.zero);
  }
}

/// A [SyncViewModel] whose running sync is controlled through [gate].
final class SyncHarness {
  SyncHarness({
    bool autoSync = false,
    bool gated = true,
    FakeSettingsRepository? settings,
    Result<List<CityDto>> cityResult = const Result.success(<CityDto>[]),
    void Function()? onCommit,
    Future<Result<List<CityDto>>> Function()? prepareCity,
  }) {
    gate = gated ? Completer<void>() : null;
    this.settings =
        settings ??
        FakeSettingsRepository(
          lastSyncedAt: autoSync ? null : DateTime.now(),
          contentSyncCursorAt: autoSync ? null : DateTime.utc(2026, 10, 12),
        );
    final useCase = SyncUseCase(
      cityRepository: _GatedCityRepository(
        gate: gate,
        prepareResult: cityResult,
        onCommit: onCommit,
        prepare: prepareCity,
        onPrepare: () => prepareCalls++,
      ),
      eventRepository: FakeEventRepository(),
      mediaRepository: FakeMediaRepository(),
      placeRepository: FakePlaceRepository(),
      settingsRepository: this.settings,
      cursorSource: FakeSyncCursorSource(),
      transactionCoordinator: FakeTransactionCoordinator(),
    );
    viewModel = SyncViewModel(syncUseCase: useCase);
  }

  int prepareCalls = 0;
  Completer<void>? gate;
  late final FakeSettingsRepository settings;
  late final SyncViewModel viewModel;

  void release() {
    gate?.complete();
  }
}

/// Gates the city preparation so the whole sync is observable as running.
final class _GatedCityRepository extends CityRepository {
  _GatedCityRepository({
    required this.gate,
    required this.prepareResult,
    this.onCommit,
    this.prepare,
    this.onPrepare,
  });

  final Completer<void>? gate;
  final Result<List<CityDto>> prepareResult;
  final void Function()? onCommit;
  final Future<Result<List<CityDto>>> Function()? prepare;
  final void Function()? onPrepare;

  @override
  Future<Result<List<CityDto>>> prepareSync({
    DateTime? modifiedAtOrAfter,
  }) async {
    onPrepare?.call();
    if (gate != null) {
      await gate!.future;
    }
    return prepare == null ? prepareResult : await prepare!();
  }

  @override
  Result<void> commitSync(List<CityDto> dtos) {
    onCommit?.call();
    return const Result.success(null);
  }
}

/// Builds the production router with the full provider tree the real screens
/// require, plus the controlled [harness] sync view model.
({GoRouter router, Widget app, ControllableAdminAuth auth}) buildSyncRouterApp(
  SyncHarness harness, {
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
    providers: buildSyncProviders(
      harness,
      auth: authHarness,
      eventRepository: eventRepository,
    ),
    child: MaterialApp.router(
      scaffoldMessengerKey: $scaffoldMessengerKey,
      routerConfig: router,
    ),
  );

  return (
    router: router,
    app: _OwnedSyncApp(harness: harness, child: app),
    auth: authHarness,
  );
}

/// Builds the production app root so the router lifecycle under theme rebuilds
/// is exercised exactly as shipped.
Widget buildRealSyncApp(SyncHarness harness) {
  final auth = ControllableAdminAuth();
  addTearDown(auth.dispose);

  return MultiProvider(
    providers: buildSyncProviders(harness, auth: auth),
    child: _OwnedSyncApp(harness: harness, child: const MoliseIsApp()),
  );
}

/// The providers the real screens resolved from the router tree require.
List<SingleChildWidget> buildSyncProviders(
  SyncHarness harness, {
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
        >(maxSize: 8),
    hourlyWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<HourlyWeatherForecastData>
        >(maxSize: 8),
    dailyWeatherCache:
        LruCache<
          String,
          WeatherForecastDataCacheEntry<DailyWeatherForecastData>
        >(maxSize: 8),
    logger: logger,
  );
  final settingsRepository = FakeSettingsRepository();
  final adminLocal = AdminDraftSessionHarness();

  return <SingleChildWidget>[
    Provider<AdminContentSubmissionRepository>.value(
      value: FakeAdminContentSubmissionRepository(),
    ),
    Provider<ContentSubmissionRepository>.value(
      value: FakeContentSubmissionRepository(),
    ),
    Provider<AdminSubmissionDraftRepository>.value(value: adminLocal.drafts),
    ChangeNotifierProvider<AdminSubmissionEditorViewModel>(
      create: (context) => AdminSubmissionEditorViewModel(
        repository: context.read<AdminContentSubmissionRepository>(),
        contentSubmissionRepository: context
            .read<ContentSubmissionRepository>(),
        draftSession: adminLocal.session,
      )..bindAuth(auth.viewModel),
    ),
    Provider<EventRepository>.value(value: eventRepo),
    Provider<PlaceRepository>.value(value: placeRepo),
    Provider<SearchRepository>.value(value: FakeSearchRepository()),
    Provider<SettingsRepository>.value(value: settingsRepository),
    Provider<CachedWeatherApiClient>.value(value: weatherApiClient),
    Provider<CacheManager>.value(value: FakeCacheManager()),
    Provider<http.Client>.value(value: RecordingTileHttpClient()),
    Provider<Logger>.value(value: logger),
    Provider<UrlLaunchService>(create: (_) => UrlLaunchService(logger: logger)),
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
        crashReporting: testCrashReporting(
          repository: settingsRepository,
          flag: SentryLoggingFlag(initialValue: false),
        ),
      ),
    ),
    ChangeNotifierProvider<SyncViewModel>.value(value: harness.viewModel),
    ChangeNotifierProvider<AdminAuthViewModel>.value(value: auth.viewModel),
  ];
}

/// Rebuilds the production router with a fresh [SyncViewModel] on restoration.
final class SyncRestorationFixture {
  SyncRestorationFixture({
    required FakeSettingsRepository settings,
    FakeEventRepository? eventRepository,
  }) : _eventRepository = eventRepository {
    harness = SyncHarness(settings: settings);
    auth = ControllableAdminAuth();
    router = buildAppRouter(
      syncViewModel: harness.viewModel,
      adminAuthViewModel: auth.viewModel,
    );
  }

  final FakeEventRepository? _eventRepository;

  /// Auth lifecycle belonging to this router instance.
  late final ControllableAdminAuth auth;

  /// Fresh sync state, with the gate released during disposal if needed.
  late final SyncHarness harness;

  /// Real application router, including its restoration scopes and pages.
  late final GoRouter router;

  /// Production providers and MaterialApp restoration root.
  Widget get app => MultiProvider(
    providers: buildSyncProviders(
      harness,
      auth: auth,
      eventRepository: _eventRepository,
    ),
    child: MaterialApp.router(
      scaffoldMessengerKey: $scaffoldMessengerKey,
      restorationScopeId: 'app',
      routerConfig: router,
    ),
  );

  /// Detaches routing before releasing any pending sync and disposing state.
  void dispose() {
    router.dispose();
    auth.dispose();

    harness.viewModel.dispose();
    final gate = harness.gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

/// Holds test state that can either persist or be recreated on restoration.
final class SyncRestorationHolder {
  SyncRestorationHolder({
    required this.settingsFactory,
    this.eventRepositoryFactory,
  });

  /// Supplies persisted or fresh settings for each process reconstruction.
  final FakeSettingsRepository Function() settingsFactory;

  /// Supplies deterministic content dependencies for each reconstruction.
  final FakeEventRepository Function()? eventRepositoryFactory;

  /// Fixture belonging to the currently mounted harness instance.
  SyncRestorationFixture? fixture;
}

/// Recreates the production router and providers after process restoration.
class RestorableSyncHarness extends StatefulWidget {
  const RestorableSyncHarness({required this.holder, super.key});

  /// Retains test access across replacement of the entire router and state.
  final SyncRestorationHolder holder;

  @override
  State<RestorableSyncHarness> createState() => _RestorableSyncHarnessState();
}

class _RestorableSyncHarnessState extends State<RestorableSyncHarness> {
  late final SyncRestorationFixture fixture = SyncRestorationFixture(
    settings: widget.holder.settingsFactory(),
    eventRepository: widget.holder.eventRepositoryFactory?.call(),
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

/// Local screen lifecycle harness: this deliberately has no routing claim.
/// Rebuilding with another owner retains the same SyncScreen State.
Widget buildLocalSyncScreen(SyncViewModel owner, {Widget? child}) =>
    ChangeNotifierProvider<SyncViewModel>.value(
      value: owner,
      child: Builder(
        builder: (context) => MaterialApp(
          scaffoldMessengerKey: $scaffoldMessengerKey,
          theme: AppThemeData.light(context: context),
          home: child ?? const SyncScreen(),
        ),
      ),
    );

/// Revokes local owners and drains their real command teardown virtually.
Future<void> disposeSyncHarnesses(
  WidgetTester tester,
  Iterable<SyncHarness> harnesses,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (final harness in harnesses) {
    harness.viewModel.dispose();
    final gate = harness.gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
  await pumpSyncRedirects(tester);
  await tester.pump(const Duration(milliseconds: 50));
  await pumpSyncRedirects(tester);
}

/// Owns the test Sync owner for the app lifetime, matching production Provider.
class _OwnedSyncApp extends StatefulWidget {
  const _OwnedSyncApp({required this.harness, required this.child});
  final SyncHarness harness;
  final Widget child;
  @override
  State<_OwnedSyncApp> createState() => _OwnedSyncAppState();
}

class _OwnedSyncAppState extends State<_OwnedSyncApp> {
  @override
  void dispose() {
    widget.harness.viewModel.dispose();
    final gate = widget.harness.gate;
    if (gate != null && !gate.isCompleted) gate.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
