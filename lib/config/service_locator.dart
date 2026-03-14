import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart';
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

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
