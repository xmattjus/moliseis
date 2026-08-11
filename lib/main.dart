import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/data/data-sources/settings_local_data_source.dart';
import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/ui/sync/view_models/sync_view_model.dart';
import 'package:moliseis/utils/constants.dart';
import 'package:moliseis/utils/http_client.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_supabase/sentry_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _sentryLoggingFlag = SentryLoggingFlag(initialValue: false);

final AppLogger _logger = AppLogger(
  $talker,
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

/// Ensures that Supabase has an anonymous session without making startup fatal.
///
/// A session restored during Supabase initialization is reused as-is. When no
/// session exists, anonymous sign-in is attempted once; expected Supabase Auth
/// failures are logged and startup continues without an authenticated user.
@visibleForTesting
Future<void> ensureAnonymousSupabaseSession({
  required GoTrueClient authClient,
  required Logger logger,
}) async {
  if (authClient.currentUser != null) return;

  try {
    await authClient.signInAnonymously();
  } on AuthException catch (error, stackTrace) {
    logger.log(
      const SupabaseAuthAnonymousLoginFailed(),
      error: error,
      stackTrace: stackTrace,
    );
  }
}

void main() async => await http.runWithClient(_main, httpClientFactory);

Future<void> _main() async {
  // Ensures the disk can be accessed before continuing app start-up.
  WidgetsFlutterBinding.ensureInitialized();

  SentryWidgetsFlutterBinding.ensureInitialized();

  // Retrieves an HTTP client instance initialized with the `runWithClient`
  // method.
  final httpClient = http.Client();

  await SentryFlutter.init(
    (options) => options
      ..dsn = Env.sentryUrl
      ..environment = kDebugMode ? 'debug' : 'production'
      ..tracesSampleRate = kDebugMode ? 0 : 0.4
      ..profilesSampleRate = kDebugMode ? 0 : 0.7
      ..replay.sessionSampleRate = kDebugMode ? 0 : 0.4
      ..replay.onErrorSampleRate = kDebugMode ? 0 : 1.0
      ..sendDefaultPii = false
      ..httpClient = httpClient
      ..enableLogs = false
      ..privacy.maskAllText = false
      ..privacy.maskAllImages = false
      ..beforeBreadcrumb = (breadcrumb, hint) {
        final message = breadcrumb?.message;

        // Drops Talker console breadcrumbs.
        if (message != null &&
            (message.contains('┌') ||
                message.contains('│ [') ||
                message.contains('└') ||
                message.contains('─['))) {
          return null;
        }

        return breadcrumb;
      },
    appRunner: () async {
      final supabase = await Supabase.initialize(
        url: Env.supabaseProdUrl,
        publishableKey: Env.supabaseProdApiKey,
        httpClient: SentrySupabaseClient(client: httpClient),
      );

      await ensureAnonymousSupabaseSession(
        authClient: supabase.client.auth,
        logger: _logger,
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

      final cacheManager = DefaultCacheManager(
        connectionParameters: ConnectionParameters(
          connectionTimeout: const Duration(
            seconds: kDefaultNetworkTimeoutSeconds,
          ),
          requestTimeout: const Duration(
            seconds: kDefaultNetworkTimeoutSeconds,
          ),
        ),
      );

      final app = MultiProvider(
        providers: providers(
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

class MoliseIsApp extends StatefulWidget {
  const MoliseIsApp({super.key});

  @override
  State<MoliseIsApp> createState() => _MoliseIsAppState();
}

class _MoliseIsAppState extends State<MoliseIsApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= buildAppRouter(
      syncViewModel: context.read<SyncViewModel>(),
    );
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = _router!;
    return Consumer<ThemeViewModel>(
      builder: (_, viewModel, _) {
        return MaterialApp.router(
          scaffoldMessengerKey: $scaffoldMessengerKey,
          restorationScopeId: 'app',
          routerConfig: router,
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
