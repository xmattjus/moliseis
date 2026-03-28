import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/data/sources/settings_local_data_source.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/exceptions.dart';
import 'package:moliseis/utils/http_client.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:moliseis/utils/sentry_talker_observer.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

final _sentryLoggingFlag = SentryLoggingFlag(initialValue: false);

final Talker _logger = TalkerFlutter.init(
  observer: SentryTalkerObserver(flag: _sentryLoggingFlag),
);

/// Logs settings initialization failures while preserving startup fallback.
@visibleForTesting
Result<void> handleSettingsRepositoryInitialization(Result<void> result) {
  if (result is Error<void>) {
    _logger.error(
      'Settings repository initialization failed. '
      'App will continue with fallback defaults.',
      result.error,
    );
  }

  return result;
}

void main() async => await runWithClient(_main, () => httpClientFactory());

Future<void> _main() async {
  // Ensures the disk can be accessed before continuing app start-up.
  SentryWidgetsFlutterBinding.ensureInitialized();

  // Retrieves an HTTP client instance initialized with the `runWithClient` method.
  final httpClient = Client();

  await SentryFlutter.init(
    (options) {
      options.dsn = Env.sentryUrl;
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for
      // tracing.
      options.tracesSampleRate = 0.4;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
      // Session Replay setup.
      options.replay.sessionSampleRate = 0.4;
      options.replay.onErrorSampleRate = 1.0;
      options.httpClient = httpClient;
    },
    appRunner: () async {
      final supabase = await Supabase.initialize(
        url: Env.supabaseProdUrl,
        anonKey: Env.supabaseProdApiKey,
        httpClient: SentrySupabaseClient(client: httpClient),
      );

      late final ObjectBox objectBox;

      try {
        objectBox = await ObjectBox.create();
      } catch (exception, stackTrace) {
        _logger.critical(
          ObjectBoxInitializationException(
            'Error: $exception, StackTrace: $stackTrace',
          ),
        );
        runApp(const SetupErrorApp());
        return;
      }

      final settingsRepository = SettingsRepositoryImpl(
        SettingsLocalDataSource(objectBox.store),
      );
      final initializeResult = await settingsRepository.initialize();
      handleSettingsRepositoryInitialization(initializeResult);

      _sentryLoggingFlag.enabled = settingsRepository.crashReporting;

      final cacheManager = CacheManager(
        Config(
          'moliseIsCacheKey',
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 100,
          fileService: HttpFileService(httpClient: httpClient),
        ),
      );

      final app = MultiProvider(
        providers: providers2(
          _logger,
          supabase,
          objectBox,
          httpClient,
          settingsRepository,
          cacheManager,
          _sentryLoggingFlag,
        ),
        child: const MoliseIsApp(),
      );

      if (settingsRepository.crashReporting) {
        _logger.info('Crash reporting is enabled. Sentry will capture errors.');

        runApp(SentryWidget(child: app));
      } else {
        await Sentry.close();

        _logger.info(
          'Crash reporting is disabled. Errors will not be sent to Sentry.',
        );

        runApp(app);
      }
    },
  );
}

class MoliseIsApp extends StatelessWidget {
  const MoliseIsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeViewModel>(
      builder: (_, viewModel, _) {
        return MaterialApp.router(
          routerConfig: appRouter,
          builder: (_, child) => child!,
          title: 'Molise Is',
          localizationsDelegates: const <LocalizationsDelegate>[
            GlobalCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale.fromSubtags(languageCode: 'en'),
            Locale.fromSubtags(languageCode: 'it'),
          ],
          theme: AppThemeData.light(context: context),
          darkTheme: AppThemeData.dark(context: context),
          themeMode: viewModel.themeMode,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

/// Minimal fallback UI displayed when app bootstrap cannot complete.
class SetupErrorApp extends StatelessWidget {
  const SetupErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'An error occurred during app setup. Please restart the app.',
          ),
        ),
      ),
    );
  }
}
