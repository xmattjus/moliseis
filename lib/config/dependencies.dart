import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:moliseis/config/env/env.dart';
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
import 'package:moliseis/data/sources/city_supabase_table.dart';
import 'package:moliseis/data/sources/event_supabase_table.dart';
import 'package:moliseis/data/sources/media_supabase_table.dart';
import 'package:moliseis/data/sources/place_supabase_table.dart';
import 'package:moliseis/data/sources/user_contribution_supabase_table.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/geo_map_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/repositories/user_contribution_repository.dart';
import 'package:moliseis/domain/use-cases/favourite/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/sync/sync_repo_use_case.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Builds the root provider list using fully initialized dependencies.
///
/// Call this only after startup services are ready in the app entrypoint.
List<SingleChildWidget> providers2(
  Talker logger,
  Supabase supabase,
  ObjectBox objectBox,
  http.Client httpClient,
  SettingsRepository settingsRepository,
  CacheManager cacheManager,
  SentryLoggingFlag sentryLoggingFlag,
) {
  return <SingleChildWidget>[
    //#region Shared
    Provider<CacheManager>.value(value: cacheManager),
    Provider<Talker>.value(value: logger),
    Provider<UrlLaunchService>(create: (_) => UrlLaunchService(logger: logger)),
    Provider<CachedWeatherApiClient>(
      create: (_) => CachedWeatherApiClient(
        weatherApiClient: WeatherApiClient(
          logger: logger,
          httpClient: httpClient,
        ),
        currentWeatherCache:
            WeatherForecastDataCache<CurrentWeatherForecastData>(maxSize: 50),
        hourlyWeatherCache: WeatherForecastDataCache<HourlyWeatherForecastData>(
          maxSize: 50,
        ),
        dailyWeatherCache: WeatherForecastDataCache<DailyWeatherForecastData>(
          maxSize: 50,
        ),
      ),
    ),
    //#endregion

    //#region Repositories (sorted by name ascending)
    Provider<PlaceRepository>(
      create: (_) =>
          PlaceRepositoryImpl(
                logger: logger,
                supabaseI: supabase,
                supabaseTable: PlaceSupabaseTable(),
                objectBoxI: objectBox,
              )
              as PlaceRepository,
    ),
    Provider<EventRepository>(
      create: (_) =>
          EventRepositoryImpl(
                logger: logger,
                supabaseI: supabase,
                supabaseTable: EventSupabaseTable(),
                objectBoxI: objectBox,
              )
              as EventRepository,
    ),
    Provider<MediaRepository>(
      create: (_) =>
          MediaRepositoryImpl(
                logger: logger,
                supabaseI: supabase,
                supabaseTable: MediaSupabaseTable(),
                objectBoxI: objectBox,
              )
              as MediaRepository,
    ),
    Provider<CityRepository>(
      create: (_) =>
          CityRepositoryImpl(
                logger: logger,
                supabaseI: supabase,
                supabaseTable: CitySupabaseTable(),
                objectBoxI: objectBox,
              )
              as CityRepository,
    ),
    Provider<SearchRepository>(
      create: (_) =>
          SearchRepositoryImpl(logger: logger, objectBoxI: objectBox)
              as SearchRepository,
    ),
    Provider<SettingsRepository>.value(value: settingsRepository),
    Provider<UserContributionRepository>(
      create: (_) {
        final cloudinaryClient = CloudinaryClient(
          logger: logger,
          cloudName: Env.cloudinaryProdCloudName,
          apiKey: Env.cloudinaryProdApiKey,
          apiSecret: Env.cloudinaryProdApiSecret,
        );

        return UserContributionRepositoryImpl(
              logger: logger,
              supabase: supabase,
              supabaseTable: UserContributionSupabaseTable(),
              cloudinaryClient: cloudinaryClient,
            )
            as UserContributionRepository;
      },
    ),
    Provider<GeoMapRepository>(
      create: (_) {
        return GeoMapRepositoryImpl(
              openStreetMapClient: OpenStreetMapClient(
                logger: logger,
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
        final useCase = SynchronizeRepositoriesUseCase(
          cityRepository: context.read(),
          eventRepository: context.read(),
          mediaRepository: context.read(),
          placeRepository: context.read(),
          settingsRepository: context.read(),
        );

        return SyncViewModel(syncRepoUseCase: useCase);
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
}
