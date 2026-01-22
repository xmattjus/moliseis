import 'dart:async' show StreamController;

import 'package:flutter/material.dart';
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/data/repositories/city_repository_impl.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/data/repositories/geo_map_repository_impl.dart';
import 'package:moliseis/data/repositories/media_repository_impl.dart';
import 'package:moliseis/data/repositories/place_repository_impl.dart';
import 'package:moliseis/data/repositories/search_repository_impl.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/data/repositories/suggestion_repository_impl.dart';
import 'package:moliseis/data/services/api/cloudinary_client.dart';
import 'package:moliseis/data/services/api/openstreetmap/openstreetmap_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/weather_forecast_data_cache_entry.dart';
import 'package:moliseis/data/services/app_info_service.dart';
import 'package:moliseis/data/services/external_url_service.dart';
import 'package:moliseis/data/services/map_url_service.dart';
import 'package:moliseis/data/services/url_launch_service.dart';
import 'package:moliseis/data/sources/city_supabase_table.dart';
import 'package:moliseis/data/sources/event_supabase_table.dart';
import 'package:moliseis/data/sources/media_supabase_table.dart';
import 'package:moliseis/data/sources/place_supabase_table.dart';
import 'package:moliseis/data/sources/suggestion_supabase_table.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/geo_map_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/repositories/suggestion_repository.dart';
import 'package:moliseis/domain/use-cases/favourite/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/sync/sync_repo_use_case.dart';
import 'package:moliseis/main.dart';
import 'package:moliseis/ui/favourite/view_models/favourite_view_model.dart';
import 'package:moliseis/ui/settings/view_models/settings_view_model.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/lru_cache.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

List<SingleChildWidget> get providers {
  return <SingleChildWidget>[
    //#region Repositories (sorted by name ascending)
    Provider(
      create: (_) {
        return PlaceRepositoryImpl(
              supabaseI: Supabase.instance,
              supabaseTable: PlaceSupabaseTable(),
              objectBoxI: objectBox,
            )
            as PlaceRepository;
      },
      lazy: true,
    ),
    Provider(
      create: (_) {
        return EventRepositoryImpl(
              supabaseI: Supabase.instance,
              supabaseTable: EventSupabaseTable(),
              objectBoxI: objectBox,
            )
            as EventRepository;
      },
    ),
    Provider(
      create: (_) {
        return MediaRepositoryImpl(
              supabaseI: Supabase.instance,
              imageSupabaseTable: MediaSupabaseTable(),
              objectBoxI: objectBox,
            )
            as MediaRepository;
      },
      lazy: true,
    ),
    Provider(
      create: (_) {
        return CityRepositoryImpl(
              supabaseI: Supabase.instance,
              placeSupabaseTable: CitySupabaseTable(),
              objectBoxI: objectBox,
            )
            as CityRepository;
      },
      lazy: true,
    ),
    Provider(
      create: (_) {
        return SearchRepositoryImpl(objectBoxI: objectBox) as SearchRepository;
      },
      lazy: true,
    ),
    Provider(
      create: (context) {
        return SettingsRepositoryImpl(objectBoxI: objectBox)
            as SettingsRepository;
      },
      lazy: true,
    ),
    Provider<SuggestionRepository>(
      create: (_) {
        final cloudinaryClient = CloudinaryClient(
          cloudName: Env.cloudinaryProdCloudName,
          apiKey: Env.cloudinaryProdApiKey,
          apiSecret: Env.cloudinaryProdApiSecret,
        );

        return SuggestionRepositoryImpl(
              supabase: Supabase.instance,
              supabaseTable: SuggestionSupabaseTable(),
              cloudinaryClient: cloudinaryClient,
            )
            as SuggestionRepository;
      },
    ),
    Provider<GeoMapRepository>(
      create: (_) {
        return GeoMapRepositoryImpl(openStreetMapClient: OpenStreetMapClient())
            as GeoMapRepository;
      },
      lazy: true,
    ),
    //#endregion

    //#region ViewModels (sorted by use!)
    ChangeNotifierProvider<ThemeViewModel>(
      create: (context) {
        return ThemeViewModel(settingsRepository: context.read());
      },
      lazy: true,
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
      lazy: true,
    ),
    ChangeNotifierProvider<SettingsViewModel>(
      create: (context) {
        return SettingsViewModel(settingsRepository: context.read());
      },
      lazy: true,
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

    //#region URL Services
    Provider<ExternalUrlService>(
      create: (_) => ExternalUrlService(),
      lazy: true,
    ),
    Provider<AppInfoService>(
      create: (context) => AppInfoService(
        externalUrlService: context.read<ExternalUrlService>(),
      ),
      lazy: true,
    ),
    Provider<MapUrlService>(
      create: (context) =>
          MapUrlService(externalUrlService: context.read<ExternalUrlService>()),
      lazy: true,
    ),
    Provider<UrlLaunchService>(
      create: (context) => UrlLaunchService(
        externalUrlService: context.read<ExternalUrlService>(),
        appInfoService: context.read<AppInfoService>(),
        mapUrlService: context.read<MapUrlService>(),
      ),
      lazy: true,
    ),
    //#endregion

    //#region Other
    Provider<StreamController<Widget>>(
      create: (_) => StreamController<Widget>.broadcast(),
      lazy: true,
      dispose: (_, value) => value.close(),
    ),
    Provider<
      LruCache<
        String,
        WeatherForecastDataCacheEntry<CurrentWeatherForecastData>
      >
    >(
      create: (_) =>
          LruCache<
            String,
            WeatherForecastDataCacheEntry<CurrentWeatherForecastData>
          >(maxSize: 50),
      lazy: true,
    ),
    Provider<
      LruCache<String, WeatherForecastDataCacheEntry<HourlyWeatherForecastData>>
    >(
      create: (_) =>
          LruCache<
            String,
            WeatherForecastDataCacheEntry<HourlyWeatherForecastData>
          >(maxSize: 50),
      lazy: true,
    ),
    Provider<
      LruCache<String, WeatherForecastDataCacheEntry<DailyWeatherForecastData>>
    >(
      create: (_) =>
          LruCache<
            String,
            WeatherForecastDataCacheEntry<DailyWeatherForecastData>
          >(maxSize: 50),
      lazy: true,
    ),
    //#endregion
  ];
}
