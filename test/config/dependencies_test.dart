import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/data/repositories/city_repository_impl.dart';
import 'package:moliseis/data/repositories/content_submission_repository_impl.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/data/repositories/media_repository_impl.dart';
import 'package:moliseis/data/repositories/place_repository_impl.dart';
import 'package:moliseis/data/repositories/search_repository_impl.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/services.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';

import '../support/fake_cache_manager.dart';
import '../support/fake_repositories.dart';
import '../support/mock_logger.dart';
import '../support/mock_supabase.dart';
import '../support/objectbox_test_store.dart';

/// An [http.Client] that never makes a real request.
///
/// Provider construction never calls the HTTP client, so this only exists to
/// satisfy the `httpClient` parameter of [providers] without engaging the
/// test binding's fake HTTP implementation.
final class _NoopHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      throw UnsupportedError('_NoopHttpClient does not make requests');
}

/// Tests that [providers] produces a fully resolvable provider tree.
///
/// Unlike a hand-rolled re-declaration, this exercises the real [providers]
/// function end-to-end: it feeds the same inputs the app passes in
/// `main.dart`, pumps the returned list through a [MultiProvider], and
/// resolves every advertised type from the build context. A dropped
/// provider, a wrong concrete type, or a dependency declared after its
/// consumer would fail here.
void main() {
  setUpAll(setUpMockSupabase);

  late MockLogger logger;
  late MockSupabaseEnvironment supabaseEnv;
  late TestObjectBoxEnvironment objectBoxEnv;
  late FakeSettingsRepository settingsRepository;
  late CacheManager cacheManager;
  late SentryLoggingFlag sentryLoggingFlag;
  late http.Client httpClient;

  setUp(() async {
    logger = MockLogger();
    // Supabase is never reached during provider construction; mark it
    // unavailable so any accidental access fails loudly instead of hitting
    // the network.
    supabaseEnv = MockSupabaseEnvironment()..stubUnavailable();
    objectBoxEnv = await TestObjectBoxEnvironment.create();
    // A recent sync timestamp keeps SyncUseCase.isSyncRequired false, so
    // SyncViewModel does not auto-trigger a real sync (Sentry + network)
    // when the provider tree is built.
    settingsRepository = FakeSettingsRepository(
      lastSyncedAt: DateTime.now(),
    );
    cacheManager = FakeCacheManager();
    sentryLoggingFlag = SentryLoggingFlag(initialValue: false);
    httpClient = _NoopHttpClient();
  });

  tearDown(() async {
    await objectBoxEnv.dispose();
    await cacheManager.dispose();
  });

  group('providers()', () {
    testWidgets('wires every advertised type into the provider tree', (
      tester,
    ) async {
      final resolved = <Type, Object?>{};

      await tester.pumpWidget(
        MultiProvider(
          providers: providers(
            logger,
            supabaseEnv.mockSupabase,
            TestObjectBox(objectBoxEnv.store),
            httpClient,
            settingsRepository,
            cacheManager,
            sentryLoggingFlag,
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                resolved[CacheManager] = context.read<CacheManager>();
                resolved[Logger] = context.read<Logger>();
                resolved[UrlLaunchService] = context.read<UrlLaunchService>();
                resolved[CachedWeatherApiClient] = context
                    .read<CachedWeatherApiClient>();
                resolved[PlaceRepository] = context.read<PlaceRepository>();
                resolved[EventRepository] = context.read<EventRepository>();
                resolved[MediaRepository] = context.read<MediaRepository>();
                resolved[CityRepository] = context.read<CityRepository>();
                resolved[SearchRepository] = context.read<SearchRepository>();
                resolved[SettingsRepository] = context
                    .read<SettingsRepository>();
                resolved[ContentSubmissionRepository] = context
                    .read<ContentSubmissionRepository>();
                resolved[ThemeViewModel] = context.read<ThemeViewModel>();
                resolved[SyncViewModel] = context.read<SyncViewModel>();
                resolved[SettingsViewModel] = context.read<SettingsViewModel>();
                resolved[FavouriteViewModel] = context
                    .read<FavouriteViewModel>();
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // Value-provided dependencies are forwarded by identity.
      expect(resolved[CacheManager], same(cacheManager));
      expect(resolved[Logger], same(logger));
      expect(resolved[SettingsRepository], same(settingsRepository));

      // Shared services are constructed inside the tree.
      expect(resolved[UrlLaunchService], isA<UrlLaunchService>());
      expect(
        resolved[CachedWeatherApiClient],
        isA<CachedWeatherApiClient>(),
      );

      // Repositories resolve to their concrete implementations.
      expect(resolved[PlaceRepository], isA<PlaceRepositoryImpl>());
      expect(resolved[EventRepository], isA<EventRepositoryImpl>());
      expect(resolved[MediaRepository], isA<MediaRepositoryImpl>());
      expect(resolved[CityRepository], isA<CityRepositoryImpl>());
      expect(resolved[SearchRepository], isA<SearchRepositoryImpl>());
      expect(
        resolved[ContentSubmissionRepository],
        isA<ContentSubmissionRepositoryImpl>(),
      );

      // View models are constructed and wired with their repositories.
      expect(resolved[ThemeViewModel], isA<ThemeViewModel>());
      expect(resolved[SyncViewModel], isA<SyncViewModel>());
      expect(resolved[SettingsViewModel], isA<SettingsViewModel>());
      expect(resolved[FavouriteViewModel], isA<FavouriteViewModel>());

      // Let the fire-and-forget FavouriteViewModel.load command settle
      // before tearDown disposes the ObjectBox store it queries.
      await tester.pumpAndSettle();
    });
  });
}
