import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/data/data-sources/settings_local_data_source.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/http_client.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_flutter/talker_flutter.dart';

final _sentryLoggingFlag = SentryLoggingFlag(initialValue: false);
final Talker talker = TalkerFlutter.init();
final AppLogger _logger = AppLogger(
  talker,
  sentryFlag: _sentryLoggingFlag,
);

/// Logs settings initialization failures while preserving startup fallback.
@visibleForTesting
void handleSettingsRepositoryInitialization(Result<void> result) {
  if (result is Error<void>) {
    _logger.log(
      const LocalPersistenceSettingsInitFailed(),
      error: result.error,
    );
  }
}

void main() async => await http.runWithClient(_main, httpClientFactory);

Future<void> _main() async {
  // Ensures the disk can be accessed before continuing app start-up.
  SentryWidgetsFlutterBinding.ensureInitialized();

  // Retrieves an HTTP client instance initialized with the `runWithClient`
  // method.
  final httpClient = http.Client();

  await SentryFlutter.init(
    (options) => options
      ..dsn = Env.sentryUrl
      ..environment = kDebugMode ? 'debug' : 'production'
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for
      // tracing.
      ..tracesSampleRate = 0.4
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      ..profilesSampleRate = 1.0
      // Session Replay setup.
      ..replay.sessionSampleRate = 0.4
      ..replay.onErrorSampleRate = 1.0
      ..httpClient = httpClient,
    appRunner: () async {
      final supabase = await Supabase.initialize(
        url: Env.supabaseProdUrl,
        anonKey: Env.supabaseProdApiKey,
        httpClient: SentrySupabaseClient(client: httpClient),
      );

      late final ObjectBox objectBox;

      try {
        objectBox = await ObjectBox.create();
      } on Object catch (error, stackTrace) {
        _logger.log(
          const LocalPersistenceInitFailed(),
          error: error,
          stackTrace: stackTrace,
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
        providers: providers(
          _logger,
          talker,
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
        _logger.log(
          const SentryLoggingEnabled(
            environment: kDebugMode ? 'debug' : 'production',
          ),
        );

        runApp(SentryWidget(child: app));
      } else {
        await Sentry.close();

        _logger.log(const SentryLoggingDisabled());

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
          restorationScopeId: 'app',
          routerConfig: appRouter,
          builder: (_, child) => child!,
          title: 'Molise Is',
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
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
