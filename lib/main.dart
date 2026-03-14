import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart';
import 'package:moliseis/config/dependencies.dart';
import 'package:moliseis/config/env/env.dart';
import 'package:moliseis/config/service_locator.dart';
import 'package:moliseis/data/services/objectbox.dart';
import 'package:moliseis/data/sources/app_settings.dart';
import 'package:moliseis/routing/router.dart';
import 'package:moliseis/ui/core/themes/app_theme_data.dart';
import 'package:moliseis/ui/settings/view_models/theme_view_model.dart';
import 'package:moliseis/utils/http_client.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';

void main() async => await runWithClient(_main, () => httpClientFactory());

Future<void> _main() async {
  // Ensures the disk can be accessed before continuing app start-up.
  WidgetsFlutterBinding.ensureInitialized();

  await setupServiceLocator();

  // Retrieves the app settings to check whether the user has given his consent
  // to report exceptions or not.
  final settings = sl<ObjectBox>().store.box<AppSettings>().get(settingsId);

  final enableSentry = (settings?.crashReporting ?? false) && !kDebugMode;

  const app = MoliseIsApp();

  if (enableSentry) {
    await SentryFlutter.init((options) {
      options.dsn = Env.sentryUrl;
      options.addIntegration(LoggingIntegration());
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for
      // tracing.
      options.tracesSampleRate = 0.4;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
      // Session Replay setup.
      options.replay.sessionSampleRate = 0.4;
      options.replay.onErrorSampleRate = 1.0;
      options.httpClient = sl<Client>();
    }, appRunner: () => runApp(SentryWidget(child: app)));
  } else {
    runApp(app);
  }
}

class MoliseIsApp extends StatelessWidget {
  const MoliseIsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: providers,
      child: Consumer<ThemeViewModel>(
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
      ),
    );
  }
}
