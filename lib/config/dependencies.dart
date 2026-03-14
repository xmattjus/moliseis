import 'dart:async' show StreamController;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/config/service_locator.dart';
import 'package:moliseis/data/repositories/city_repository_impl.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/data/repositories/geo_map_repository_impl.dart';
import 'package:moliseis/data/repositories/media_repository_impl.dart';
import 'package:moliseis/data/repositories/place_repository_impl.dart';
import 'package:moliseis/data/repositories/search_repository_impl.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/data/repositories/user_contribution_repository_impl.dart';
import 'package:moliseis/data/services/api/cloudinary_client.dart';
import 'package:moliseis/data/services/api/openstreetmap/openstreetmap_client.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
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
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

List<SingleChildWidget> get providers {
  return <SingleChildWidget>[
    //#region Repositories (sorted by name ascending)
    Provider(
      create: (_) {
        return PlaceRepositoryImpl(
              supabaseI: sl<Supabase>(),
              supabaseTable: PlaceSupabaseTable(),
              objectBoxI: sl<ObjectBox>(),
            )
            as PlaceRepository;
      },
    ),
    Provider(
      create: (_) {
        return EventRepositoryImpl(
              supabaseI: sl<Supabase>(),
              supabaseTable: EventSupabaseTable(),
              objectBoxI: sl<ObjectBox>(),
            )
            as EventRepository;
      },
    ),
    Provider(
      create: (_) {
        return MediaRepositoryImpl(
              supabaseI: sl<Supabase>(),
              supabaseTable: MediaSupabaseTable(),
              objectBoxI: sl<ObjectBox>(),
            )
            as MediaRepository;
      },
    ),
    Provider(
      create: (_) {
        return CityRepositoryImpl(
              supabaseI: sl<Supabase>(),
              supabaseTable: CitySupabaseTable(),
              objectBoxI: sl<ObjectBox>(),
            )
            as CityRepository;
      },
    ),
    Provider(
      create: (_) {
        return SearchRepositoryImpl(objectBoxI: sl<ObjectBox>())
            as SearchRepository;
      },
    ),
    Provider(
      create: (_) {
        return SettingsRepositoryImpl(objectBoxI: sl<ObjectBox>())
            as SettingsRepository;
      },
    ),
    Provider<UserContributionRepository>(
      create: (_) {
        final cloudinaryClient = CloudinaryClient(
          cloudName: Env.cloudinaryProdCloudName,
          apiKey: Env.cloudinaryProdApiKey,
          apiSecret: Env.cloudinaryProdApiSecret,
        );

        return UserContributionRepositoryImpl(
              supabase: sl<Supabase>(),
              supabaseTable: UserContributionSupabaseTable(),
              cloudinaryClient: cloudinaryClient,
            )
            as UserContributionRepository;
      },
    ),
    Provider<GeoMapRepository>(
      create: (_) {
        return GeoMapRepositoryImpl(openStreetMapClient: OpenStreetMapClient())
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
        return SettingsViewModel(settingsRepository: context.read());
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

    //#region Other
    Provider<UrlLaunchService>(create: (_) => UrlLaunchService()),
    Provider<StreamController<Widget>>(
      create: (_) => StreamController<Widget>.broadcast(),
      dispose: (_, value) => value.close(),
    ),
    Provider<WeatherForecastDataCache<CurrentWeatherForecastData>>(
      create: (_) =>
          WeatherForecastDataCache<CurrentWeatherForecastData>(maxSize: 50),
    ),
    Provider<WeatherForecastDataCache<HourlyWeatherForecastData>>(
      create: (_) =>
          WeatherForecastDataCache<HourlyWeatherForecastData>(maxSize: 50),
    ),
    Provider<WeatherForecastDataCache<DailyWeatherForecastData>>(
      create: (_) =>
          WeatherForecastDataCache<DailyWeatherForecastData>(maxSize: 50),
    ),
    Provider<CacheManager>(create: (_) => sl<CacheManager>()),
    //#endregion
  ];
}
