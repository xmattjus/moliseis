import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/data/sources/settings_local_data_source.dart';
import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/result.dart';
import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;
final _log = Logger('ServiceLocator');

@visibleForTesting
Result<void> handleSettingsRepositoryInitialization(Result<void> result) {
  if (result is Error<void>) {
    _log.severe(
      'Settings repository initialization failed. '
      'App will continue with fallback defaults.',
      result.error,
    );
  }

  return result;
}

Future<void> setupServiceLocator() async {
  sl.registerSingleton<Client>(Client());
  sl.registerSingletonAsync<Supabase>(
    () async => await Supabase.initialize(
      url: Env.supabaseProdUrl,
      anonKey: Env.supabaseProdApiKey,
      httpClient: SentrySupabaseClient(client: sl<Client>()),
    ),
  );
  sl.registerSingletonAsync<ObjectBox>(() async => await ObjectBox.create());
  sl.registerSingletonAsync<SettingsRepository>(() async {
    final settingsRepository = SettingsRepositoryImpl(
      SettingsLocalDataSource(sl<ObjectBox>().store),
    );
    final initializeResult = await settingsRepository.initialize();
    handleSettingsRepositoryInitialization(initializeResult);
    return settingsRepository;
  }, dependsOn: [ObjectBox]);
  sl.registerSingleton<CacheManager>(
    CacheManager(
      Config(
        'moliseIsCacheKey',
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 100,
        fileService: HttpFileService(httpClient: sl<Client>()),
      ),
    ),
  );

  await sl.allReady();
}
