import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart'
    show CacheManager;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/data/core/objectbox_sync_transaction_coordinator.dart';
import 'package:moliseis/data/repositories/admin_content_submission_repository_impl.dart';
import 'package:moliseis/data/repositories/city_repository_impl.dart';
import 'package:moliseis/data/repositories/content_submission_draft_repository_impl.dart';
import 'package:moliseis/data/repositories/content_submission_repository_impl.dart';
import 'package:moliseis/data/repositories/content_submission_staged_asset_repository_impl.dart';
import 'package:moliseis/data/repositories/event_repository_impl.dart';
import 'package:moliseis/data/repositories/media_repository_impl.dart';
import 'package:moliseis/data/repositories/place_repository_impl.dart';
import 'package:moliseis/data/repositories/search_repository_impl.dart';
import 'package:moliseis/data/services/api/cloudinary/cloudinary_upload_client_impl.dart';
import 'package:moliseis/data/services/api/cloudinary/supabase_cloudinary_upload_preparation_client.dart';
import 'package:moliseis/data/services/api/weather/cached_weather_api_client.dart';
import 'package:moliseis/data/services/api/weather/model/current_forecast/current_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/daily_forecast/daily_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/model/hourly_forecast/hourly_weather_forecast_data.dart';
import 'package:moliseis/data/services/api/weather/weather_api_client.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/data/services/services.dart';
import 'package:moliseis/domain/repositories/admin_content_submission_repository.dart';
import 'package:moliseis/domain/repositories/city_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_draft_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_repository.dart';
import 'package:moliseis/domain/repositories/content_submission_staged_asset_repository.dart';
import 'package:moliseis/domain/repositories/event_repository.dart';
import 'package:moliseis/domain/repositories/media_repository.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/domain/repositories/search_repository.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/domain/use-cases/favourite_get_ids_use_case.dart';
import 'package:moliseis/domain/use-cases/sync_use_case.dart';
import 'package:moliseis/ui/admin/auth/view_models/admin_auth_view_model.dart';
import 'package:moliseis/ui/content_submission/view_models/content_submission_view_model.dart';
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
///
/// The `$` character in the name is used to clearly indicate that this
/// instance is intentionally global/static.
final Talker $talker = TalkerFlutter.init();

/// The global [ScaffoldMessengerState] instance.
///
/// The Dependency Injection pattern is intentionally not used here because
/// this key must be eagerly available at the application root during the
/// initialization of MaterialApp, and its lifecycle is tied permanently
/// to the single global widget tree, making DI an unnecessary abstraction
/// layer that introduces boilerplate without providing flexibility or
/// mockability.
///
/// The `$` character in the name is used to clearly indicate that this
/// instance is intentionally global/static.
final GlobalKey<ScaffoldMessengerState> $scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

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
  Provider<AdminContentSubmissionRepository>(
    create: (context) =>
        AdminContentSubmissionRepositoryImpl(
              logger: context.read(),
              supabaseClient: supabase.client,
            )
            as AdminContentSubmissionRepository,
  ),
  Provider<PlaceRepository>(
    create: (context) =>
        PlaceRepositoryImpl(
              logger: context.read(),
              supabaseI: supabase,
              objectBoxI: objectBox,
            )
            as PlaceRepository,
  ),
  Provider<EventRepository>(
    create: (context) =>
        EventRepositoryImpl(
              logger: context.read(),
              supabaseI: supabase,
              objectBoxI: objectBox,
            )
            as EventRepository,
  ),
  Provider<MediaRepository>(
    create: (context) =>
        MediaRepositoryImpl(
              logger: context.read(),
              supabaseI: supabase,
              objectBoxI: objectBox,
            )
            as MediaRepository,
  ),
  Provider<CityRepository>(
    create: (context) =>
        CityRepositoryImpl(
              logger: context.read(),
              supabaseI: supabase,
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
  Provider<ContentSubmissionRepository>(
    create: (context) {
      final cloudinaryUploadClient = CloudinaryUploadClientImpl(
        logger: context.read(),
        cloudName: Env.cloudinaryProdCloudName,
        preparationClient: SupabaseCloudinaryUploadPreparationClient(
          client: supabase.client,
        ),
      );

      return ContentSubmissionRepositoryImpl(
            logger: context.read(),
            supabase: supabase,
            cloudinaryUploadClient: cloudinaryUploadClient,
          )
          as ContentSubmissionRepository;
    },
    dispose: (_, repository) => repository.dispose(),
  ),
  Provider<ContentSubmissionDraftRepository>(
    create: (context) => ContentSubmissionDraftRepositoryImpl(
      logger: context.read(),
      objectBoxI: objectBox,
    ),
  ),
  Provider<ContentSubmissionStagedAssetRepository>(
    create: (context) => ContentSubmissionStagedAssetRepositoryImpl(
      logger: context.read(),
      objectBoxI: objectBox,
    ),
  ),
  //#endregion

  //#region ViewModels (sorted by use!)
  ChangeNotifierProvider<AdminAuthViewModel>(
    create: (context) => AdminAuthViewModel(
      authClient: supabase.client.auth,
      logger: context.read(),
    ),
  ),
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
        transactionCoordinator: ObjectBoxSyncTransactionCoordinator(
          objectBox.store,
        ),
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
  ChangeNotifierProvider(
    create: (context) {
      final viewModel = ContentSubmissionViewModel(
        logger: context.read<Logger>(),
        contentSubmissionRepository: context
            .read<ContentSubmissionRepository>(),
        draftRepository: context.read<ContentSubmissionDraftRepository>(),
        stagedAssetRepository: context
            .read<ContentSubmissionStagedAssetRepository>(),
      );
      unawaited(viewModel.initialize());
      return viewModel;
    },
  ),
  //#endregion
];
