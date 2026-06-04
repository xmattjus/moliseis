import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/data/data-sources/city_supabase_table.dart';
import 'package:moliseis/data/data-sources/event_supabase_table.dart';
import 'package:moliseis/data/data-sources/media_supabase_table.dart';
import 'package:moliseis/data/data-sources/place_supabase_table.dart';
import 'package:moliseis/data/data-sources/user_contribution_supabase_table.dart';
import 'package:moliseis/data/repositories/city_repository_impl.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/data/repositories/geo_map_repository_impl.dart';
import 'package:moliseis/data/repositories/media_repository_impl.dart';
import 'package:moliseis/data/repositories/place_repository_impl.dart';
import 'package:moliseis/data/repositories/search_repository_impl.dart';
import 'package:moliseis/data/repositories/user_contribution_repository_impl.dart';
import 'package:moliseis/data/services/api/cloudinary_client.dart';
import 'package:moliseis/data/services/api/openstreetmap/openstreetmap_client.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/weather_api_client.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/data/services/services.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/geo_map_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/repositories/user_contribution_repository.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// The global [Talker] instance.
///
/// The Dependency Injection pattern is intentionally not used here because
/// go_router route observers do not have access to the build context.
/// The `$` character in the name is used to clearly indicate that this
/// instance is intentionally global/static.
final Talker $talker = TalkerFlutter.init();

/// Builds the root provider list using fully initialized dependencies.
///
/// Call this only after startup services are ready in the app entrypoint.
List<SingleChildWidget> providers(
  Logger logger,
  Supabase supabase,
  ObjectBox objectBox,
  http.Client httpClient,
  SettingsRepository settingsRepository,
  CacheManager cacheManager,
  SentryLoggingFlag sentryLoggingFlag,
) => <SingleChildWidget>[
  //#region Shared
  Provider<CacheManager>.value(value: cacheManager),
  Provider<Logger>.value(value: logger),
  Provider<UrlLaunchService>(
    create: (context) => UrlLaunchService(
      logger: context.read(),
    ),
  ),
  Provider<CachedWeatherApiClient>(
    create: (context) => CachedWeatherApiClient(
      weatherApiClient: WeatherApiClient(
        logger: context.read(),
        httpClient: httpClient,
      ),
      currentWeatherCache: WeatherForecastDataCache<CurrentWeatherForecastData>(
        maxSize: 50,
      ),
      hourlyWeatherCache: WeatherForecastDataCache<HourlyWeatherForecastData>(
        maxSize: 50,
      ),
      dailyWeatherCache: WeatherForecastDataCache<DailyWeatherForecastData>(
        maxSize: 50,
      ),
      logger: context.read(),
    ),
  ),
  //#endregion

  //#region Repositories (sorted by name ascending)
  Provider<PlaceRepository>(
    create: (context) =>
        PlaceRepositoryImpl(
              logger: context.read(),
              supabaseI: supabase,
              supabaseTable: PlaceSupabaseTable(),
              objectBoxI: objectBox,
            )
            as PlaceRepository,
  ),
  Provider<EventRepository>(
    create: (context) =>
        EventRepositoryImpl(
              logger: context.read(),
              supabaseI: supabase,
              supabaseTable: EventSupabaseTable(),
              objectBoxI: objectBox,
            )
            as EventRepository,
  ),
  Provider<MediaRepository>(
    create: (context) =>
        MediaRepositoryImpl(
              logger: context.read(),
              supabaseI: supabase,
              supabaseTable: MediaSupabaseTable(),
              objectBoxI: objectBox,
            )
            as MediaRepository,
  ),
  Provider<CityRepository>(
    create: (context) =>
        CityRepositoryImpl(
              logger: context.read(),
              supabaseI: supabase,
              supabaseTable: CitySupabaseTable(),
              objectBoxI: objectBox,
            )
            as CityRepository,
  ),
  Provider<SearchRepository>(
    create: (context) =>
        SearchRepositoryImpl(logger: context.read(), objectBoxI: objectBox)
            as SearchRepository,
  ),
  Provider<SettingsRepository>.value(value: settingsRepository),
  Provider<UserContributionRepository>(
    create: (context) {
      final cloudinaryClient = CloudinaryClient(
        logger: context.read(),
        cloudName: Env.cloudinaryProdCloudName,
        apiKey: Env.cloudinaryProdApiKey,
        apiSecret: Env.cloudinaryProdApiSecret,
      );

      return UserContributionRepositoryImpl(
            logger: context.read(),
            supabase: supabase,
            supabaseTable: UserContributionSupabaseTable(),
            cloudinaryClient: cloudinaryClient,
          )
          as UserContributionRepository;
    },
  ),
  Provider<GeoMapRepository>(
    create: (context) {
      return GeoMapRepositoryImpl(
            openStreetMapClient: OpenStreetMapClient(
              logger: context.read(),
              httpClient: httpClient,
            ),
          )
          as GeoMapRepository;
    },
  ),
  //#endregion

  //#region ViewModels (sorted by use!)
  ChangeNotifierProvider<ThemeViewModel>(
    create: (context) {
      return ThemeViewModel(settingsRepository: context.read());
    },
  ),
  ChangeNotifierProvider<SyncViewModel>(
    create: (context) {
      final syncUseCase = SyncUseCase(
        cityRepository: context.read(),
        eventRepository: context.read(),
        mediaRepository: context.read(),
        placeRepository: context.read(),
        settingsRepository: context.read(),
      );

      return SyncViewModel(syncUseCase: syncUseCase);
    },
  ),
  ChangeNotifierProvider<SettingsViewModel>(
    create: (context) {
      return SettingsViewModel(
        settingsRepository: context.read(),
        sentryLoggingFlag: sentryLoggingFlag,
      );
    },
  ),
  ChangeNotifierProvider<FavouriteViewModel>(
    create: (context) {
      return FavouriteViewModel(
        favouriteGetIdsUseCase: FavouriteGetIdsUseCase(
          eventRepository: context.read(),
          placeRepository: context.read(),
        ),
      );
    },
  ),
  //#endregion
];
